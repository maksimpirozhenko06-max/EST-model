% Pre-processing script for the EST Simulink model. This script is invoked
% before the Simulink model starts running (initFcn callback function).

%% Load the supply and demand data

timeUnit   = 's';

supplyFile = "Team01_supply.csv";
supplyUnit = "kW";

% load the supply data
Supply = loadSupplyData(supplyFile, timeUnit, supplyUnit);

demandFile = "Team01_demand.csv";
demandUnit = "kW";

% load the demand data
Demand = loadDemandData(demandFile, timeUnit, demandUnit);

%% Simulation settings

deltat = 900*unit("s");
stopt  = min([Supply.Timeinfo.End, Demand.Timeinfo.End]);

%% System parameters

% TRANSPORT FROM SUPPLY
cableResistivity = 1.676e-8; % Cable material resistivity (Copper) (Ohm * m)
cableArea = 6e-6; % Cable cross sectional area (m^2). Assumed DC at 480V and 20A.
current = 20; % Current (I) flowing (Amperes)
cableLength = 28.5; % Length of cable from solar panels to controller

% INJECTION SYSTEM
% tank geometry
volumeTank = 30; % Volume (m^3)
sideLength = volumeTank^(1/3); % Side of the cube (m)
areaTank = 6 * (sideLength^2); % Total surface area (m^2)
thicknessSteel = 0.015; % Steel thickness (m)
thicknessInsulation = 0.10; % Insulation thickness (m)

% materials
densityGel = 720; % Silica gel bulk density (kg/m^3)
densitySteel = 7850; % Steel density (kg/m^3)
heatCapacityGel = 840; % Silica gel heat capacity (J/kgK)
heatCapacitySteel = 490; % Steel heat capacity (J/kgK)
kSteel = 54; % Steel thermal conductivity (W/mK)
kInsulation = 0.04; % Insulation thermal conductivity (W/mK)
massGel = volumeTank * densityGel;
massSteel = areaTank * thicknessSteel * densitySteel;
mCpTotal = (massGel * heatCapacityGel) + (massSteel * heatCapacitySteel);

% efficiency and environment
hAir = 10; % Convection coeff (W/m^2K)
emissivitySurface = 0.5;               
stefanBoltz = 5.67e-8; % Stefan-Boltzmann Constant
efficiencyInjection = 0.98; % Conversion efficiency
tempEnv = 293.15; % Environment temperature (K)    

% STORAGE SYSTEM
EStorageMax     = 5000.*unit("kWh");
EStorageMin     = 200.*unit("kWh");
EStorageInitial = 1500.*unit("kWh");   

% sorption system characteristics (silica gel / water)
ms = massGel;          % Sorbent mass (kg), based on full tank volume
cps = 920;             % Specific heat capacity of sorbent (J/kgK)
dh_ads = 2.5e6;        % Heat of adsorption (J/kg_water)
UA = 15;               % Heat loss coefficient (W/K)
kLdf = 0.008;          % Linear driving force coefficient (1/s) % Linear driving force coefficient (1/s)

% Dubinin-Astakhov model
X0 = 0.35; % Maximum loading (kg water/kg sorbent)
E = 6000; % Characteristic adsorption energy (J/mol)
n = 1.5; % Exponent (-)
pv = 1200; % Vapor pressure (Pa)
% Reference state for stored-energy calculation:
% fully loaded sorbent at ambient temperature is treated as empty storage.
Tref = tempEnv;
Xref = 0.05;

XStorageInitial = 0.05;
TStorageInitial = tempEnv;
TStorageInitial = Tref;

% EXTRACTION SYSTEM
alphaLoss = 0.1; % Dissipation coefficient

% TRANSPORT TO DEMAND
alphaSplit = 0.7; % Percentage of energy destined for heating
cableLengthDemand = 20; % Length of cable from extraction to demand (m)
currentDemand = 2.5; % Amperage at apartment (A)
r1 = 0.03; % Inner radius of heating pipe
r2 = 0.035; % Outer radius of heating pipe
r3 = 0.05; % Outer radius of heating pipe insulation
pipeLength = 10; % Length of pipe from extraction to apartment
kPipe = 0.3; % Pipe material (PEX) thermal conductivity (W/mK)
emissivitySurfacePipe = 0.9;
Tfluid = 353.15; % Temperature of the fluid inside the pipe (K)

% Data-based daylight window from supply file
Sunrise = zeros(365,1);
Sunset  = zeros(365,1);

threshold = 0.05 * max(Supply.Data); % 5% of max supply

for d = 1:365

    idx = floor(Supply.Time / 86400) + 1 == d;

    tDay = Supply.Time(idx);
    pDay = Supply.Data(idx);

    active = pDay > threshold;

    if any(active)
        Sunrise(d) = mod(tDay(find(active,1,'first')), 86400) / 3600;
        Sunset(d)  = mod(tDay(find(active,1,'last')), 86400) / 3600;
    else
        Sunrise(d) = 12;
        Sunset(d)  = 12;
    end
end

dayTime = ((0:364)' * 86400);   % seconds

SunriseSignal = timeseries(Sunrise, dayTime);
SunsetSignal  = timeseries(Sunset, dayTime);

%% Battery Settings

EBatteryMax     = 5000.*unit("kWh");
EBatteryMin     = 200.*unit("kWh");
EBatteryInitial = 1500.*unit("kWh");