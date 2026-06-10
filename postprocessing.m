% Post-processing script for the EST Simulink model.
% This script is invoked after the Simulink model finishes running
% through the StopFcn callback.
%% ------------------------------------------------------------------------
%  1. Setup and unit conversions
% -------------------------------------------------------------------------
close all;
secondsPerDay = 86400;
J_per_kWh     = 3.6e6;

% Core styling variables for universal coherence throughout all tabs
fontName   = 'Helvetica';
colorSolar = [0.20, 0.40, 0.65];  % Professional Muted Blue
colorSorp  = [0.85, 0.55, 0.25];  % Warm Amber
colorBatt  = [0.15, 0.55, 0.45];  % Deep Teal
colorGrid  = [0.65, 0.25, 0.25];  % Muted Crimson / Burgundy
colorDark  = [0.15, 0.15, 0.15];  % Soft Off-Black for text

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
PSupply = getSignal(["PSupply", "PfromSupplyTransport"], nSamples, 0); 
PDemand = getSignal("PDemand", nSamples, 0);                           
PdirectHeat = getSignal("PdirectHeat", nSamples, 0);                   
PdirectElec = getSignal("PdirectElec", nSamples, 0);                   
PSell = getSignal(["PSell", "Psell", "Pcurtailed"], nSamples, 0);      
PunmetHeat = getSignal("PunmetHeat", nSamples, 0);                     
PunmetElec = getSignal("PunmetElec", nSamples, 0);                     
PBuyLogged = getSignal(["PBuy", "Pbuy"], nSamples, NaN);               
if all(isnan(PBuyLogged))
    PBuy = PunmetHeat + PunmetElec;                                    
else
    PBuy = PBuyLogged;                                                 
end
PtoSorptionInjection = getSignal(["PtoSorptionInjection", "PtoInjection"], nSamples, 0); 
PfromSorptionInjection = getSignal("PfromSorptionInjection", nSamples, NaN);             
PtoBatteryInjection  = getSignal("PtoBatteryInjection", nSamples, 0);                    
if all(isnan(PfromSorptionInjection))
    PfromSorptionInjection = PtoSorptionInjection;
end
PfromSorptionStorage = getSignal(["PfromSorptionStorage", "PfromExtraction"], nSamples, 0); 
PfromBattery         = getSignal(["PfromBattery", "PfromExtractionBattery"], nSamples, 0);  
PSorptionToDemand = getSignal(["PSorptionToDemand", "PtoDemandSorption"], nSamples, 0); 
PBatteryToDemand  = getSignal(["PBatteryToDemand", "PtoDemandBattery"], nSamples, 0);   
PfromDemandTransport = getSignal("PfromDemandTransport", nSamples, 0); 
DDemandTransport     = getSignal("DDemandTransport", nSamples, 0);     
PheatDelivered       = getSignal("PheatDelivered", nSamples, 0);       
PelecDelivered       = getSignal("PelecDelivered", nSamples, 0);       
ESorption = getSignal(["EStorage", "ESorption"], nSamples, NaN);           
EBattery  = getSignal(["EStorageBattery", "EBattery"], nSamples, NaN);     
DSupplyTransport = getSignal("DSupplyTransport", nSamples, 0);             
DStorage         = getSignal("DStorage", nSamples, 0);                     
DExtraction      = getSignal("DExtraction", nSamples, 0);                  
DExtractionBatt  = getSignal(["DExtractionBattery", "DBatteryExtraction"], nSamples, 0); 
DTotalLogged = getSignal("D", nSamples, NaN);                              
if all(isnan(DTotalLogged))
    DTotal = DSupplyTransport + DDemandTransport + DStorage + DExtraction + DExtractionBatt;
else
    DTotal = DTotalLogged;
end

%% ------------------------------------------------------------------------
%  2B. Sorption stored energy from energy accounting
% -------------------------------------------------------------------------
dt_seconds = [0; diff(t)];
PsorptionCharge_kW    = PfromSorptionInjection(:);   
PsorptionDischarge_kW = PfromSorptionStorage(:);      
PsorptionLoss_kW = zeros(nSamples, 1);
dE_sorption_kWh = (PsorptionCharge_kW - PsorptionDischarge_kW - PsorptionLoss_kW) .* dt_seconds / 3600;
E_sorption_graph_kWh = EStorageInitial / J_per_kWh + cumsum(dE_sorption_kWh);
E_sorption_graph_kWh = max(EStorageMin / J_per_kWh, min(EStorageMax / J_per_kWh, E_sorption_graph_kWh));

%% ------------------------------------------------------------------------
%  3. Energy balance calculations
% -------------------------------------------------------------------------
EfromSupplyTransport_kWh = powerIntegral_kWh(t, PSupply);
EDemandRequested_kWh     = powerIntegral_kWh(t, PDemand);
EDirectHeat_kWh = powerIntegral_kWh(t, PdirectHeat);
EDirectElec_kWh = powerIntegral_kWh(t, PdirectElec);
EDirect_kWh     = EDirectHeat_kWh + EDirectElec_kWh;
EtoSorption_kWh = powerIntegral_kWh(t, PtoSorptionInjection);
EtoBattery_kWh  = powerIntegral_kWh(t, PtoBatteryInjection);
ESell_kWh       = powerIntegral_kWh(t, PSell);
EBuy_kWh        = powerIntegral_kWh(t, PBuy);
EfromSorption_kWh   = powerIntegral_kWh(t, PfromSorptionStorage);
EfromBattery_kWh    = powerIntegral_kWh(t, PfromBattery);
ESorptionUseful_kWh = powerIntegral_kWh(t, PSorptionToDemand);
EBatteryUseful_kWh  = powerIntegral_kWh(t, PBatteryToDemand);
ElossTotal_kWh      = powerIntegral_kWh(t, DTotal);

customColors = [colorSolar; colorSorp; colorBatt; colorGrid];

%% ------------------------------------------------------------------------
%  4. Main overview plots
% -------------------------------------------------------------------------
figure("Name", "EST System Overview", "Color", "w", "WindowStyle", "docked");
tLayout = tiledlayout(3, 1, "TileSpacing", "compact", "Padding", "compact");

% Subplot 1: Supply and demand
nexttile;
plot(tDays, PSupply, "LineWidth", 1.5, "Color", colorSolar); hold on;
plot(tDays, PDemand, "LineWidth", 1.5, "Color", colorGrid);
grid on; set(gca, 'FontName', fontName);
title("Supply and Demand Profiles", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Power [kW]");
legend("Supply after transport", "Demand", "Location", "best");
xlim([0 max(tDays)]);

% Subplot 2: Losses
nexttile;
plot(tDays, DTotal, "LineWidth", 1.5, "Color", colorGrid);
grid on; set(gca, 'FontName', fontName);
title("Total System Loss Dissipation Rate", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Dissipation Rate [kW]");
xlim([0 max(tDays)]);

% Subplot 3: Load balancing
nexttile;
plot(tDays, PSell, "LineWidth", 1.5, "Color", colorSolar); hold on;
plot(tDays, PBuy, "LineWidth", 1.5, "Color", colorGrid);
grid on; set(gca, 'FontName', fontName);
title("System Load Balancing Matrix", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Power [kW]");
legend("Sell / Curtailed", "Buy / Unmet", "Location", "best");
xlim([0 max(tDays)]);

%% ------------------------------------------------------------------------
%  5. Stacked Dynamic Delivered Energy Mix Timeline
% -------------------------------------------------------------------------
dt_steps = [0; diff(t)]; 

E_Direct_cum   = cumsum(max(0, PdirectHeat + PdirectElec) .* dt_steps) / 3600;
E_Sorption_cum = cumsum(max(0, PSorptionToDemand) .* dt_steps) / 3600;
E_Battery_cum  = cumsum(max(0, PBatteryToDemand) .* dt_steps) / 3600;
E_Bought_cum   = cumsum(max(0, PBuy) .* dt_steps) / 3600;
E_Total_cum    = E_Direct_cum + E_Sorption_cum + E_Battery_cum + E_Bought_cum;

pct_Direct   = zeros(size(tDays));
pct_Sorption = zeros(size(tDays));
pct_Battery  = zeros(size(tDays));
pct_Bought   = zeros(size(tDays));

validIdx = E_Total_cum > 0;
pct_Direct(validIdx)   = (E_Direct_cum(validIdx) ./ E_Total_cum(validIdx)) * 100;
pct_Sorption(validIdx) = (E_Sorption_cum(validIdx) ./ E_Total_cum(validIdx)) * 100;
pct_Battery(validIdx)  = (E_Battery_cum(validIdx) ./ E_Total_cum(validIdx)) * 100;
pct_Bought(validIdx)   = (E_Bought_cum(validIdx) ./ E_Total_cum(validIdx)) * 100;

stackedMatrix = [pct_Direct, pct_Sorption, pct_Battery, pct_Bought];

figure('Name', 'Report: Stacked Energy Source Mix Timeline', 'Color', 'w', 'WindowStyle', 'docked');
areaPlot = area(tDays, stackedMatrix, 'EdgeColor', 'none');
grid on; set(gca, 'Layer', 'top', 'FontName', fontName, 'XColor', colorDark, 'YColor', colorDark); 

for idx = 1:numel(areaPlot)
    areaPlot(idx).FaceColor = customColors(idx, :);
    areaPlot(idx).FaceAlpha = 0.85;
end

xlabel('Time [day]', 'FontWeight', 'bold', 'FontName', fontName);
ylabel('Cumulative Contribution Share [%]', 'FontWeight', 'bold', 'FontName', fontName);
title('Dynamic Delivered Energy Mix Evolution', 'FontWeight', 'bold', 'FontSize', 12, 'FontName', fontName);
xlim([0 max(tDays)]); ylim([0 100]); 

legendLabels = { ...
    sprintf('Direct Solar Supply (Final: %.1f%%)', pct_Direct(end)), ...
    sprintf('Sorption Storage (Final: %.1f%%)', pct_Sorption(end)), ...
    sprintf('Battery Storage (Final: %.1f%%)', pct_Battery(end)), ...
    sprintf('Grid Bought / Unmet (Final: %.1f%%)', pct_Bought(end)) ...
};
legend(legendLabels, 'Location', 'best', 'FontName', fontName);

%% ------------------------------------------------------------------------
%  6. Energy breakdown pie charts
% -------------------------------------------------------------------------
figure("Name", "EST Energy Breakdown", "Color", "w", "WindowStyle", "docked");
tiledlayout(1, 2, "TileSpacing", "loose", "Padding", "compact");

% Received solar energy breakdown
ax1 = nexttile;
receivedValues = [EDirect_kWh, EtoSorption_kWh, EtoBattery_kWh, ESell_kWh];
receivedLabels = {"Direct to demand", "To sorption storage", "To battery", "Sold / curtailed"};
safePie(ax1, receivedValues, receivedLabels, customColors);
title(ax1, sprintf("Received Solar Infrastructure\nTotal Input: %.1f kWh", EfromSupplyTransport_kWh), ...
    "FontWeight", "bold", "FontName", fontName, "FontSize", 11);

% Delivered / balanced energy breakdown
ax2 = nexttile;
deliveredValues = [EDirect_kWh, ESorptionUseful_kWh, EBatteryUseful_kWh, EBuy_kWh];
deliveredLabels = {"Direct from supply", "From sorption storage", "From battery", "Bought / unmet"};
safePie(ax2, deliveredValues, deliveredLabels, customColors);
title(ax2, sprintf("Demand-Side Consumption Mix\nTotal Pool: %.1f kWh", EDirect_kWh + ESorptionUseful_kWh + EBatteryUseful_kWh + EBuy_kWh), ...
    "FontWeight", "bold", "FontName", fontName, "FontSize", 11);

%% ------------------------------------------------------------------------
%  7. Battery diagnostics
% -------------------------------------------------------------------------
figure("Name", "Battery Diagnostics", "Color", "w", "WindowStyle", "docked");
tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plot(tDays, PfromBattery, "LineWidth", 1.5, "Color", colorBatt);
grid on; set(gca, 'FontName', fontName);
title("Battery Dynamic Discharge Command", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Power [kW]");
xlim([0 max(tDays)]);

nexttile;
if ~all(isnan(EBattery))
    plot(tDays, EBattery / J_per_kWh, "LineWidth", 1.5, "Color", colorBatt); hold on;
    yline(EBatteryMin / J_per_kWh, "--", "Battery min", 'Color', colorGrid, 'LineWidth', 1.2);
    yline(EBatteryMax / J_per_kWh, "--", "Battery max", 'Color', colorSolar, 'LineWidth', 1.2);
end
grid on; set(gca, 'FontName', fontName);
title("Battery Stored Energy Timeline", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Energy [kWh]");
xlim([0 max(tDays)]);
if ~all(isnan(EBattery)), ylim([min(EBattery/J_per_kWh)*0.9 max(EBattery/J_per_kWh)*1.1]); end

%% ------------------------------------------------------------------------
%  8. Seven-day battery window (Tab 5 - Placed Immediately After Battery Diagnostics)
% -------------------------------------------------------------------------
figure("Name", "Battery Weekly Cycle", "Color", "w", "WindowStyle", "docked");
if ~all(isnan(EBattery))
    plot(tDays, EBattery / J_per_kWh, "LineWidth", 1.8, "Color", colorBatt);
    xlim([150 157]); 
end
grid on; set(gca, 'FontName', fontName);
title("High-Resolution Battery Cycling Dynamics (7-Day Micro-Window)", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Energy [kWh]");

%% ------------------------------------------------------------------------
%  9. Sorption diagnostics
% -------------------------------------------------------------------------
figure("Name", "Sorption Diagnostics", "Color", "w", "WindowStyle", "docked");
tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plot(tDays, PfromSorptionStorage, "LineWidth", 1.5, "Color", colorSorp);
grid on; set(gca, 'FontName', fontName);
title("Sorption Storage Extraction Profile", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Power [kW]");
xlim([0 max(tDays)]);

nexttile;
if ~all(isnan(ESorption))
    plot(tDays, ESorption / J_per_kWh, "LineWidth", 1.5, "Color", colorSorp); hold on;
    yline(EStorageMin / J_per_kWh, "--", "Sorption min", 'Color', colorGrid, 'LineWidth', 1.2);
    yline(EStorageMax / J_per_kWh, "--", "Sorption max", 'Color', colorSolar, 'LineWidth', 1.2);
end
grid on; set(gca, 'FontName', fontName);
title("Sorption Stored Energy Timeline", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Energy [kWh]");
xlim([0 max(tDays)]);
if ~all(isnan(ESorption)), ylim([min(ESorption/J_per_kWh)*0.9 max(ESorption/J_per_kWh)*1.1]); end

%% ------------------------------------------------------------------------
%  10. Combined storage comparison
% -------------------------------------------------------------------------
figure("Name", "Storage Comparison", "Color", "w", "WindowStyle", "docked");
if ~all(isnan(EBattery))
    plot(tDays, EBattery / J_per_kWh, "LineWidth", 1.6, "Color", colorBatt); hold on;
end
plot(tDays, E_sorption_graph_kWh, "LineWidth", 1.6, "Color", colorSorp);
grid on; set(gca, 'FontName', fontName);
title("Inter-Asset Storage Reserve Comparison", "FontWeight", "bold");
xlabel("Time [day]"); ylabel("Energy [kWh]");
legend("Battery Bank Reserve", "Sorption Buffer Reserve", "Location", "best");
xlim([0 max(tDays)]);

%% ------------------------------------------------------------------------
%  11. Printed summary
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
    if ischar(names), names = string(names); end
    y = [];
    for i = 1:numel(names)
        name = names(i);
        if evalin("base", sprintf("exist('%s','var')", name))
            raw = evalin("base", name); y = unpackSignal(raw); break;
        end
    end
    if isempty(y)
        if isempty(nSamples), y = []; else y = defaultValue * ones(nSamples, 1); end
        return;
    end
    y = y(:); if isempty(nSamples), return; end
    if isscalar(y), y = y * ones(nSamples, 1);
    elseif length(y) > nSamples, y = y(1:nSamples);
    elseif length(y) < nSamples, y(end+1:nSamples, 1) = y(end);
    end
end

function y = unpackSignal(raw)
    if isnumeric(raw), y = raw; return; end
    if isa(raw, "timeseries") || isa(raw, "Simulink.SimulationData.Signal")
        y = squeeze(raw.Data); return;
    end
    if isstruct(raw) && isfield(raw, "Data"), y = squeeze(raw.Data); return; end
    y = [];
end

function E_kWh = powerIntegral_kWh(t, P_kW)
    if isempty(t) || isempty(P_kW) || all(isnan(P_kW)), E_kWh = 0; return; end
    E_kWh = trapz(t, max(0, P_kW(:))) / 3600;
end

function safePie(ax, values, labels, cmap)
    values = values(:); values(~isfinite(values)) = 0; values(values < 0) = 0;
    keep = values > 1e-9;
    if ~any(keep)
        text(ax, 0.5, 0.5, "No energy flow data", "HorizontalAlignment", "center", "VerticalAlignment", "middle");
        axis(ax, "off"); return;
    end
    pPatches = pie(ax, values(keep));
    styleIdx = 1; filteredCmap = cmap(keep, :);
    for k = 1:numel(pPatches)
        if isa(pPatches(k), 'matlab.graphics.primitive.Patch')
            pPatches(k).FaceColor = filteredCmap(styleIdx, :);
            pPatches(k).EdgeColor = 'w'; pPatches(k).LineWidth = 1.2;
            styleIdx = styleIdx + 1;
        elseif isa(pPatches(k), 'matlab.graphics.shape.Text')
            pPatches(k).FontName = 'Helvetica'; pPatches(k).FontSize = 9;
        end
    end
    legend(ax, labels(keep), "Location", "southoutside", "FontSize", 9, "FontName", "Helvetica");
end