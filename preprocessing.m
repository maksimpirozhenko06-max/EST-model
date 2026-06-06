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

% Tank geometry
volumeTank = 30;                     % [m^3]
sideLength = volumeTank^(1/3);       % [m], cube side length
areaTank   = 6 * sideLength^2;       % [m^2]

thicknessSteel      = 0.015;         % [m]
thicknessInsulation = 0.10;          % [m]

% Material properties
densityGel   = 720;                  % [kg/m^3] silica gel bulk density
densitySteel = 7850;                 % [kg/m^3]

heatCapacityGel   = 840;             % [J/kg/K]
heatCapacitySteel = 490;             % [J/kg/K]

kSteel      = 54;                    % [W/m/K]
kInsulation = 0.04;                  % [W/m/K]

% Masses
massGel   = volumeTank * densityGel;
massSteel = areaTank * thicknessSteel * densitySteel;

% Combined heat capacity for injection/tank calculations
mCpTotal = massGel * heatCapacityGel + massSteel * heatCapacitySteel;

% External heat transfer properties
hAir                = 10;            % [W/m^2/K]
emissivitySurface   = 0.5;
efficiencyInjection = 0.98;          % sorption charging conversion efficiency

%% ------------------------------------------------------------------------
%  6. Sorption storage parameters
% -------------------------------------------------------------------------

% Sorption energy limits
% Stored energy is in J.
EStorageMax     = 5000 * 3.6e6;      % [J] 5000 kWh
EStorageMin     = 100  * 3.6e6;      % [J] 200 kWh
EStorageInitial = 1200 * 3.6e6;      % [J] 1500 kWh

% Sorption material properties
ms     = massGel;                    % [kg] sorbent mass
cps    = 920;                        % [J/kg/K] sorbent heat capacity
dh_ads = 2.5e6;                      % [J/kg_water] heat of adsorption
UA     = 15;                         % [W/K] tank heat loss coefficient
kLdf   = 0.008;                      % [1/s] linear driving force coefficient

% Dubinin-Astakhov model parameters
X0   = 0.35;                         % [kg water/kg sorbent] maximum loading
E_DA = 6000;                         % [J/mol] characteristic adsorption energy
E    = E_DA;                         % keep variable name E for current Storage block input
n    = 1.5;                          % [-]
pv   = 1200;                         % [Pa] vapor pressure

% Reference state for stored energy
% Wet/high loading = discharged/empty thermal storage.
Tref = tempEnv;
Xref = X0;

% Initial sorption temperature
TStorageInitial = Tref;

% Make initial X consistent with EStorageInitial:
% Echemical = ms * dh_ads * (Xref - X)
XStorageInitial = Xref - EStorageInitial / (ms * dh_ads);

% Clamp XStorageInitial to physical range [0, X0]
XStorageInitial = max(0.0, min(X0, XStorageInitial));

% If you want to force an empty/discharged sorption tank instead, use:
% EStorageInitial = 0;
% XStorageInitial = X0;

% If you want to force a fully charged/dry sorption tank instead, use:
% XStorageInitial = 0.05;
% EStorageInitial = ms * dh_ads * (Xref - XStorageInitial);

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

% Sorption is seasonal heat storage, so charge it more slowly.
PmaxSorptionCharge    = 5;           % [kW]
PmaxSorptionDischarge = 15;          % [kW]

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
%  12. Quick checks
% -------------------------------------------------------------------------

fprintf("Preprocessing complete.\n");
fprintf("Sorption initial energy: %.1f kWh\n", EStorageInitial / 3.6e6);
fprintf("Sorption initial X: %.4f kg/kg\n", XStorageInitial);
fprintf("Battery initial energy: %.1f kWh\n", EBatteryInitial / 3.6e6);