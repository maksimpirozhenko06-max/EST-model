% Pre-processing script for the EST Simulink model.
% This script is invoked before the Simulink model starts running
% through the InitFcn callback.

clearvars -except Supply Demand

%% ------------------------------------------------------------------------
%  1. Load supply and demand data
% -------------------------------------------------------------------------

timeUnit = 's';

supplyFile = "Team01_supply.csv";
supplyUnit = "kW";
Supply = loadSupplyData(supplyFile, timeUnit, supplyUnit);

demandFile = "Team01_demand.csv";
demandUnit = "kW";
Demand = loadDemandData(demandFile, timeUnit, demandUnit);

%% ------------------------------------------------------------------------
%  2. Simulation settings
% -------------------------------------------------------------------------

dtController = 900;          % [s] controller/storage time step
deltat       = 900;          % [s] fixed simulation time step

stopt = min([Supply.Timeinfo.End, Demand.Timeinfo.End]);

%% ------------------------------------------------------------------------
%  3. General constants
% -------------------------------------------------------------------------

epsilon = 1e-9;

stefanBoltz = 5.67e-8;       % [W/m^2/K^4]
tempEnv     = 293.15;        % [K] ambient/environment temperature

%% ------------------------------------------------------------------------
%  4. Transport from supply
% -------------------------------------------------------------------------

cableResistivity = 1.676e-8; % [Ohm*m] copper
cableArea        = 6e-6;     % [m^2]
current          = 20;       % [A]
cableLength      = 28.5;     % [m] supply to controller

%% ------------------------------------------------------------------------
%  5. Sorption tank geometry and materials
% -------------------------------------------------------------------------

% Tank configuration
numberOfTanks = 1;
totalVolumeTank = 30;              % [m^3] total storage volume

% Single tank geometry
volumeTankSingle = totalVolumeTank / numberOfTanks;
sideLengthSingle = volumeTankSingle^(1/3);
areaTankSingle   = 6 * sideLengthSingle^2;

% Total system geometry
areaTank = numberOfTanks * areaTankSingle;

% Material thickness
thicknessSteel      = 0.015;       % [m]
thicknessInsulation = 0.10;        % [m]

% Material properties
densityGel   = 720;                % [kg/m^3]
densitySteel = 7850;               % [kg/m^3]

heatCapacityGel   = 840;           % [J/kg/K]
heatCapacitySteel = 490;           % [J/kg/K]

kSteel      = 54;                  % [W/m/K]
kInsulation = 0.04;                % [W/m/K]

% Total system masses
massGel = totalVolumeTank * densityGel;
massSteel = areaTank * thicknessSteel * densitySteel;

% Combined heat capacity of the entire storage system
mCpTotal = massGel * heatCapacityGel + ...
           massSteel * heatCapacitySteel;

% External heat transfer
hAir = 10;                         % [W/m^2/K]
emissivitySurface = 0.5;

% -------------------------------------------------------------------------
% Regeneration temperature
% -------------------------------------------------------------------------

Tregeneration = 65;                % [°C] target silica drying temperature
TregenerationK = Tregeneration + 273.15;

deltaTreg = TregenerationK - tempEnv;
Qheating = mCpTotal * deltaTreg;   % [J]

% -------------------------------------------------------------------------
% Thermal injection efficiency
% -------------------------------------------------------------------------

Rsteel = thicknessSteel / (kSteel * areaTank);
Rinsulation = thicknessInsulation / (kInsulation * areaTank);
Rconv = 1 / (hAir * areaTank);

Rtotal = Rsteel + Rinsulation + Rconv;

% Heat loss estimate at regeneration temperature
Qloss = deltaTreg / Rtotal;        % [W]

% Reference charging power
Pref = 5000;                       % [W]

% Raw thermal efficiency before limits
etaRaw = 1 - Qloss / Pref;

% Keep efficiency physical, but do not force everything to 0.8
efficiencyInjection = max(0.01, min(0.99, etaRaw));

% Reference system (original model)
volumeTankReference = 30;
massGelReference = volumeTankReference * densityGel;

sizeFactor = massGel / massGelReference;

% Sorption energy limits
EStorageMaxReference = 5000 * 3.6e6;
EStorageMinReference = 100  * 3.6e6;
EStorageInitialReference = 1200 * 3.6e6;

EStorageMax     = EStorageMaxReference * sizeFactor;
EStorageMin     = EStorageMinReference * sizeFactor;
EStorageInitial = EStorageInitialReference * sizeFactor;

% Sorption material properties
ms     = massGel;
cps    = 920;
dh_ads = 2.5e6;
UA     = 15;
kLdf   = 0.008;

% Dubinin-Astakhov model parameters
X0   = 0.35;
E_DA = 6000;
E    = E_DA;
n    = 1.5;
pv   = 1200;

Tref = tempEnv;
Xref = X0;

TStorageInitial = Tref;

XStorageInitial = Xref - EStorageInitial / (ms * dh_ads);

XStorageInitial = max(0.0, min(X0, XStorageInitial));

%% ------------------------------------------------------------------------
%  7. Battery storage parameters
% -------------------------------------------------------------------------

EBatteryMax     = 200 * 3.6e6;      % [J] 200 kWh
EBatteryMin     = 0  * 3.6e6;      % [J] 0 kWh
EBatteryInitial = 200 * 3.6e6;      % [J] 50 kWh

efficiencyBatteryCharge = 0.95;
etaBatteryDischarge     = 0.95;

%% ------------------------------------------------------------------------
%  8. Controller power limits
% -------------------------------------------------------------------------

% Battery is daily-cycle storage.
PmaxBatteryCharge    = 20;           % [kW]
PmaxBatteryDischarge = 20;           % [kW]

% Sorption power limits scale with the size of one tank.
% Smaller individual tanks can charge/discharge faster because the
% characteristic diffusion/heat-transfer length is shorter.

volumeTankSingleReference = 30;      % [m^3] original one-tank system

singleTankRateFactor = ...
    (volumeTankSingleReference / volumeTankSingle)^(1/3);

PmaxSorptionChargeReference    = 5;  % [kW]
PmaxSorptionDischargeReference = 15; % [kW]

PmaxSorptionCharge = ...
    PmaxSorptionChargeReference * singleTankRateFactor;

PmaxSorptionDischarge = ...
    PmaxSorptionDischargeReference * singleTankRateFactor;

% Seasonal controller settings
% Day numbers are approximate:
% 1 = Jan 1, 121 = May 1, 273 = Sep 30, 274 = Oct 1
sorptionChargeStartDay = 121;        % May 1
sorptionChargeEndDay   = 273;        % Sep 30

heatingSeasonStartDay = 274;         % Oct 1
heatingSeasonEndDay   = 120;         % Apr 30

%% ------------------------------------------------------------------------
%  9. Extraction parameters
% -------------------------------------------------------------------------

alphaLoss = 0.15;                     % [-] sorption extraction loss
etaSorptionExtraction = 1 - alphaLoss;

%% ------------------------------------------------------------------------
%  10. Demand split and transport to demand
% -------------------------------------------------------------------------

% alphaSplit is the fraction of total demand that is heating.
% 0.7 means 70% heat demand, 30% electric demand.
alphaSplit = 0.7;

% Electrical demand transport
cableLengthDemand = 20;              % [m]
currentDemand     = 2.5;             % [A]

% Heating pipe geometry
r1 = 0.03;                           % [m] inner radius
r2 = 0.035;                          % [m] outer pipe radius
r3 = 0.05;                           % [m] outer insulation radius

pipeLength = 10;                     % [m]
kPipe      = 0.3;                    % [W/m/K] PEX pipe

emissivitySurfacePipe = 0.9;
Tfluid = 353.15;                     % [K] heating fluid temperature

%% ------------------------------------------------------------------------
%  11. Data-based daylight window from supply file
% -------------------------------------------------------------------------

Sunrise = zeros(365,1);
Sunset  = zeros(365,1);

threshold = 0.05 * max(Supply.Data); % 5% of maximum supply

for d = 1:365

    idx = floor(Supply.Time / 86400) + 1 == d;

    tDay = Supply.Time(idx);
    pDay = Supply.Data(idx);

    active = pDay > threshold;

    if any(active)
        Sunrise(d) = mod(tDay(find(active, 1, 'first')), 86400) / 3600;
        Sunset(d)  = mod(tDay(find(active, 1, 'last')),  86400) / 3600;
    else
        Sunrise(d) = 12;
        Sunset(d)  = 12;
    end
end

dayTime = ((0:364)' * 86400);        % [s]

SunriseSignal = timeseries(Sunrise, dayTime);
SunsetSignal  = timeseries(Sunset,  dayTime);


%% ------------------------------------------------------------------------
%  12. Small final check-ups
% -------------------------------------------------------------------------
fprintf("\n");
fprintf("Number of tanks: %d\n", numberOfTanks);
fprintf("Total volume: %.2f m^3\n", totalVolumeTank);
fprintf("Single tank volume: %.2f m^3\n", volumeTankSingle);
fprintf("Total area: %.2f m^2\n", areaTank);
fprintf("Regeneration temperature: %.1f C\n", Tregeneration);
fprintf("Regeneration heating energy: %.1f kWh\n", Qheating / 3.6e6);
fprintf("Thermal loss estimate: %.1f W\n", Qloss);
fprintf("Raw injection efficiency: %.4f\n", etaRaw);
fprintf("Used injection efficiency: %.4f\n", efficiencyInjection);
fprintf("\n");
fprintf("Single tank volume: %.2f m^3\n", volumeTankSingle);
fprintf("Single tank rate factor: %.3f\n", singleTankRateFactor);
fprintf("Pmax sorption charge: %.2f kW\n", PmaxSorptionCharge);
fprintf("Pmax sorption discharge: %.2f kW\n", PmaxSorptionDischarge);