% Post-processing script for the EST Simulink model.
% This script is invoked after the Simulink model finishes running
% through the StopFcn callback.

%% ------------------------------------------------------------------------
%  1. Setup and unit conversions
% -------------------------------------------------------------------------

close all;

secondsPerDay = 86400;
J_per_kWh     = 3.6e6;

% Most power signals in the model are in kW.
% Stored energy signals are in J.

t = getSignal("tout", [], NaN);

if isempty(t) || all(isnan(t))
    error("Postprocessing stopped: variable 'tout' was not found.");
end

t = t(:);
nSamples = length(t);
tDays = t / secondsPerDay;

fprintf("\nPostprocessing started.\n");

%% ------------------------------------------------------------------------
%  2. Load main signals safely
% -------------------------------------------------------------------------

% Supply and demand
PSupply = getSignal(["PSupply", "PfromSupplyTransport"], nSamples, 0); % [kW]
PDemand = getSignal("PDemand", nSamples, 0);                           % [kW]

% Direct demand signals from controller
PdirectHeat = getSignal("PdirectHeat", nSamples, 0);                   % [kW]
PdirectElec = getSignal("PdirectElec", nSamples, 0);                   % [kW]

% Controller balancing signals
PSell = getSignal(["PSell", "Psell", "Pcurtailed"], nSamples, 0);      % [kW]

PunmetHeat = getSignal("PunmetHeat", nSamples, 0);                     % [kW]
PunmetElec = getSignal("PunmetElec", nSamples, 0);                     % [kW]

PBuyLogged = getSignal(["PBuy", "Pbuy"], nSamples, NaN);               % [kW]

if all(isnan(PBuyLogged))
    PBuy = PunmetHeat + PunmetElec;                                    % [kW]
else
    PBuy = PBuyLogged;                                                 % [kW]
end

% Storage charging powers
PtoSorptionInjection = getSignal(["PtoSorptionInjection", "PtoInjection"], nSamples, 0); % [kW]
PfromSorptionInjection = getSignal("PfromSorptionInjection", nSamples, NaN);             % [kW]
PtoBatteryInjection  = getSignal("PtoBatteryInjection", nSamples, 0);                    % [kW]

% If useful sorption injection output is not logged, fall back to controller command.
if all(isnan(PfromSorptionInjection))
    PfromSorptionInjection = PtoSorptionInjection;
end

% Storage discharge commands
PfromSorptionStorage = getSignal(["PfromSorptionStorage", "PfromExtraction"], nSamples, 0); % [kW]
PfromBattery         = getSignal(["PfromBattery", "PfromExtractionBattery"], nSamples, 0);  % [kW]

% Useful extraction outputs, if logged
PSorptionToDemand = getSignal(["PSorptionToDemand", "PtoDemandSorption"], nSamples, 0); % [kW]
PBatteryToDemand  = getSignal(["PBatteryToDemand", "PtoDemandBattery"], nSamples, 0);   % [kW]

% Demand transport outputs
PfromDemandTransport = getSignal("PfromDemandTransport", nSamples, 0); % [kW]
DDemandTransport     = getSignal("DDemandTransport", nSamples, 0);     % [kW]
PheatDelivered       = getSignal("PheatDelivered", nSamples, 0);       % [kW]
PelecDelivered       = getSignal("PelecDelivered", nSamples, 0);       % [kW]

% Stored energies
ESorption = getSignal(["EStorage", "ESorption"], nSamples, NaN);           % [J]
EBattery  = getSignal(["EStorageBattery", "EBattery"], nSamples, NaN);     % [J]

% Losses
DSupplyTransport = getSignal("DSupplyTransport", nSamples, 0);             % [kW]
DStorage         = getSignal("DStorage", nSamples, 0);                     % [kW]
DExtraction      = getSignal("DExtraction", nSamples, 0);                  % [kW]
DExtractionBatt  = getSignal(["DExtractionBattery", "DBatteryExtraction"], nSamples, 0); % [kW]

DTotalLogged = getSignal("D", nSamples, NaN);                              % [kW]

if all(isnan(DTotalLogged))
    DTotal = DSupplyTransport + DDemandTransport + DStorage + DExtraction + DExtractionBatt;
else
    DTotal = DTotalLogged;
end

%% ------------------------------------------------------------------------
%  2B. Sorption stored energy from energy accounting
% -------------------------------------------------------------------------

% This is a system-level state of charge for sorption storage.
% It avoids the square-wave behaviour caused by using temperature/loading
% directly from the sorption physics block.

dt_seconds = [0; diff(t)];

PsorptionCharge_kW    = PfromSorptionInjection(:);   % useful power into sorption storage
PsorptionDischarge_kW = PfromSorptionStorage(:);      % raw power removed from sorption storage

% For now, do not subtract DStorage here.
% DStorage can contain thermal tank loss and may distort the storage graph.
PsorptionLoss_kW = zeros(nSamples, 1);

dE_sorption_kWh = ...
    (PsorptionCharge_kW ...
    - PsorptionDischarge_kW ...
    - PsorptionLoss_kW) .* dt_seconds / 3600;

E_sorption_graph_kWh = EStorageInitial / J_per_kWh + cumsum(dE_sorption_kWh);

% Clamp to storage limits
E_sorption_graph_kWh = max(EStorageMin / J_per_kWh, ...
    min(EStorageMax / J_per_kWh, E_sorption_graph_kWh));

%% ------------------------------------------------------------------------
%  3. Main overview plots
% -------------------------------------------------------------------------

figure("Name", "EST System Overview");

tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");

% Supply and demand
nexttile;
plot(tDays, PSupply, "LineWidth", 1.2);
hold on;
plot(tDays, PDemand, "LineWidth", 1.2);
grid on;
title("Supply and demand");
xlabel("Time [day]");
ylabel("Power [kW]");
legend("Supply after transport", "Demand", "Location", "best");

% Stored energy
nexttile;
hold on;

plot(tDays, E_sorption_graph_kWh, "LineWidth", 1.2);

if ~all(isnan(EBattery))
    plot(tDays, EBattery / J_per_kWh, "LineWidth", 1.2);
end


grid on;
title("Stored energy");
xlabel("Time [day]");
ylabel("Energy [kWh]");
legend("Sorption", "Battery", "Location", "best");

% Losses
nexttile;
plot(tDays, DTotal, "LineWidth", 1.2);
grid on;
title("Total losses");
xlabel("Time [day]");
ylabel("Dissipation rate [kW]");

% Load balancing
nexttile;
plot(tDays, PSell, "LineWidth", 1.2);
hold on;
plot(tDays, PBuy, "LineWidth", 1.2);
grid on;
title("Load balancing");
xlabel("Time [day]");
ylabel("Power [kW]");
legend("Sell / curtailed", "Buy / unmet", "Location", "best");

%% ------------------------------------------------------------------------
%  4. Energy balance calculations
% -------------------------------------------------------------------------

EfromSupplyTransport_kWh = powerIntegral_kWh(t, PSupply);
EDemandRequested_kWh     = powerIntegral_kWh(t, PDemand);

EDirectHeat_kWh = powerIntegral_kWh(t, PdirectHeat);
EDirectElec_kWh = powerIntegral_kWh(t, PdirectElec);
EDirect_kWh     = EDirectHeat_kWh + EDirectElec_kWh;

EtoSorption_kWh = powerIntegral_kWh(t, PtoSorptionInjection);
EtoBattery_kWh  = powerIntegral_kWh(t, PtoBatteryInjection);

ESell_kWh = powerIntegral_kWh(t, PSell);
EBuy_kWh  = powerIntegral_kWh(t, PBuy);

EfromSorption_kWh = powerIntegral_kWh(t, PfromSorptionStorage);
EfromBattery_kWh  = powerIntegral_kWh(t, PfromBattery);

ESorptionUseful_kWh = powerIntegral_kWh(t, PSorptionToDemand);
EBatteryUseful_kWh  = powerIntegral_kWh(t, PBatteryToDemand);

EheatDelivered_kWh = powerIntegral_kWh(t, PheatDelivered);
EelecDelivered_kWh = powerIntegral_kWh(t, PelecDelivered);
Edelivered_kWh     = EheatDelivered_kWh + EelecDelivered_kWh;

ElossTotal_kWh = powerIntegral_kWh(t, DTotal);

%% ------------------------------------------------------------------------
%  5. Energy breakdown pie charts
% -------------------------------------------------------------------------

figure("Name", "EST Energy Breakdown");

tiledlayout(1, 2, "TileSpacing", "compact", "Padding", "compact");

% Received solar energy breakdown
ax1 = nexttile;

receivedValues = [ ...
    EDirect_kWh, ...
    EtoSorption_kWh, ...
    EtoBattery_kWh, ...
    ESell_kWh];

receivedLabels = { ...
    "Direct to demand", ...
    "To sorption storage", ...
    "To battery", ...
    "Sold / curtailed"};

safePie(ax1, receivedValues, receivedLabels);
title(ax1, sprintf("Received solar energy: %.1f kWh", EfromSupplyTransport_kWh));

% Delivered / balanced energy breakdown
ax2 = nexttile;

deliveredValues = [ ...
    EDirect_kWh, ...
    ESorptionUseful_kWh, ...
    EBatteryUseful_kWh, ...
    EBuy_kWh];

deliveredLabels = { ...
    "Direct from supply", ...
    "From sorption storage", ...
    "From battery", ...
    "Bought / unmet"};

safePie(ax2, deliveredValues, deliveredLabels);
title(ax2, sprintf("Demand-side energy: %.1f kWh", EDirect_kWh + ESorptionUseful_kWh + EBatteryUseful_kWh + EBuy_kWh));

%% ------------------------------------------------------------------------
%  6. Battery diagnostics
% -------------------------------------------------------------------------

figure("Name", "Battery Diagnostics");

tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plot(tDays, PfromBattery, "LineWidth", 1.2);
grid on;
title("Battery discharge command");
xlabel("Time [day]");
ylabel("Power [kW]");

nexttile;
if ~all(isnan(EBattery))
    plot(tDays, EBattery / J_per_kWh, "LineWidth", 1.2);
    hold on;
    yline(EBatteryMin / J_per_kWh, "--", "Battery min");
    yline(EBatteryMax / J_per_kWh, "--", "Battery max");
end
grid on;
title("Battery stored energy");
xlabel("Time [day]");
ylabel("Energy [kWh]");
legend("Battery energy", "Min limit", "Max limit", "Location", "best");

%% ------------------------------------------------------------------------
%  7. Sorption diagnostics
% -------------------------------------------------------------------------

figure("Name", "Sorption Diagnostics");

tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plot(tDays, PfromSorptionStorage, "LineWidth", 1.2);
grid on;
title("Sorption discharge command");
xlabel("Time [day]");
ylabel("Power [kW]");

nexttile;
if ~all(isnan(ESorption))
    plot(tDays, ESorption / J_per_kWh, "LineWidth", 1.2);
    hold on;
    yline(EStorageMin / J_per_kWh, "--", "Sorption min");
    yline(EStorageMax / J_per_kWh, "--", "Sorption max");
end
grid on;
title("Sorption stored energy");
xlabel("Time [day]");
ylabel("Energy [kWh]");
legend("Sorption energy", "Min limit", "Max limit", "Location", "best");

%% ------------------------------------------------------------------------
%  8. Combined storage comparison
% -------------------------------------------------------------------------

figure("Name", "Storage Comparison");

hold on;

if ~all(isnan(EBattery))
    plot(tDays, EBattery / J_per_kWh, "LineWidth", 1.2);
end

plot(tDays, E_sorption_graph_kWh, "LineWidth", 1.2);

grid on;
title("Battery and sorption storage comparison");
xlabel("Time [day]");
ylabel("Energy [kWh]");
legend("Battery", "Sorption", "Location", "best");

%% ------------------------------------------------------------------------
%  9. Seven-day battery window
% -------------------------------------------------------------------------

figure("Name", "Battery Weekly Cycle");

if ~all(isnan(EBattery))
    plot(tDays, EBattery / J_per_kWh, "LineWidth", 1.2);
    xlim([150 157]);
end

grid on;
title("Battery stored energy over a 7-day window");
xlabel("Time [day]");
ylabel("Energy [kWh]");

%% ------------------------------------------------------------------------
%  10. Printed summary
% -------------------------------------------------------------------------

fprintf("\nEnergy Summary:\n");
fprintf("Solar received after transport: %.2f kWh\n", EfromSupplyTransport_kWh);
fprintf("Demand requested:               %.2f kWh\n", EDemandRequested_kWh);
fprintf("Direct to demand:               %.2f kWh\n", EDirect_kWh);
fprintf("To sorption injection:          %.2f kWh\n", EtoSorption_kWh);
fprintf("To battery injection:           %.2f kWh\n", EtoBattery_kWh);
fprintf("Sold / curtailed:               %.2f kWh\n", ESell_kWh);
fprintf("Bought / unmet:                 %.2f kWh\n", EBuy_kWh);
fprintf("Total modelled losses:          %.2f kWh\n", ElossTotal_kWh);

fprintf("\nBattery Summary:\n");
fprintf("Charged to battery injection:   %.2f kWh\n", EtoBattery_kWh);
fprintf("Discharged from battery:        %.2f kWh\n", EfromBattery_kWh);

if ~all(isnan(EBattery))
    fprintf("Battery initial:                %.2f kWh\n", EBattery(1) / J_per_kWh);
    fprintf("Battery maximum:                %.2f kWh\n", max(EBattery) / J_per_kWh);
    fprintf("Battery minimum:                %.2f kWh\n", min(EBattery) / J_per_kWh);
    fprintf("Battery final:                  %.2f kWh\n", EBattery(end) / J_per_kWh);
end

fprintf("\nSorption Summary:\n");
fprintf("Charged to sorption injection:  %.2f kWh\n", EtoSorption_kWh);
fprintf("Discharged from sorption:       %.2f kWh\n", EfromSorption_kWh);

if ~all(isnan(ESorption))
    fprintf("Sorption initial:               %.2f kWh\n", ESorption(1) / J_per_kWh);
    fprintf("Sorption maximum:               %.2f kWh\n", max(ESorption) / J_per_kWh);
    fprintf("Sorption minimum:               %.2f kWh\n", min(ESorption) / J_per_kWh);
    fprintf("Sorption final:                 %.2f kWh\n", ESorption(end) / J_per_kWh);
end

fprintf("\nPostprocessing complete.\n");

%% ------------------------------------------------------------------------
%  Local helper functions
% -------------------------------------------------------------------------

function y = getSignal(names, nSamples, defaultValue)
%GETSIGNAL Safely reads a signal from the base workspace.
% names can be a string or string array of possible variable names.
% If no variable is found, a default vector is returned.

    if ischar(names)
        names = string(names);
    end

    y = [];

    for i = 1:numel(names)
        name = names(i);

        if evalin("base", sprintf("exist('%s','var')", name))
            raw = evalin("base", name);
            y = unpackSignal(raw);
            break;
        end
    end

    if isempty(y)
        if isempty(nSamples)
            y = [];
        else
            y = defaultValue * ones(nSamples, 1);
        end
        return;
    end

    y = y(:);

    if isempty(nSamples)
        return;
    end

    if isscalar(y)
        y = y * ones(nSamples, 1);
    elseif length(y) > nSamples
        y = y(1:nSamples);
    elseif length(y) < nSamples
        y(end+1:nSamples, 1) = y(end);
    end
end

function y = unpackSignal(raw)
%UNPACKSIGNAL Converts common Simulink logging formats to numeric vectors.

    if isnumeric(raw)
        y = raw;
        return;
    end

    if isa(raw, "timeseries")
        y = raw.Data;
        y = squeeze(y);
        return;
    end

    if isa(raw, "Simulink.SimulationData.Signal")
        y = raw.Values.Data;
        y = squeeze(y);
        return;
    end

    if isstruct(raw)
        if isfield(raw, "signals") && isfield(raw.signals, "values")
            y = raw.signals.values;
            y = squeeze(y);
            return;
        end

        if isfield(raw, "Data")
            y = raw.Data;
            y = squeeze(y);
            return;
        end
    end

    y = [];
end

function E_kWh = powerIntegral_kWh(t, P_kW)
%POWERINTEGRAL_KWH Integrates power in kW over time in seconds.
% kW * s / 3600 = kWh.

    if isempty(t) || isempty(P_kW) || all(isnan(P_kW))
        E_kWh = 0;
        return;
    end

    P_kW = max(0, P_kW(:));
    E_kWh = trapz(t, P_kW) / 3600;
end

function safePie(ax, values, labels)
%SAFEPIE Creates a pie chart without crashing if values are zero/missing.

    values = values(:);
    values(~isfinite(values)) = 0;
    values(values < 0) = 0;

    keep = values > 1e-9;

    if ~any(keep)
        text(ax, 0.5, 0.5, "No energy flow data", ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle");
        axis(ax, "off");
        return;
    end

    pie(ax, values(keep));
    legend(ax, labels(keep), "Location", "southoutside");
end