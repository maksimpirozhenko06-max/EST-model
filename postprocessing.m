% Post-processing script for the EST Simulink model. This script is invoked
% after the Simulink model is finished running (stopFcn callback function).

close all;
figure;

%% Supply and demand
subplot(2,2,1);
plot(tout/unit("day"), PSupply/unit("W"));
hold on;
plot(tout/unit("day"), PDemand/unit("W"));
xlim([0 tout(end)/unit("day")]);
grid on;
title('Supply and demand');
xlabel('Time [day]');
ylabel('Power [W]');
legend("Supply","Demand");

%% Stored energy
subplot(2,2,2);
plot(tout/unit("day"), EStorage/unit("J"));
xlim([0 tout(end)/unit("day")]);
grid on;
title('Storage');
xlabel('Time [day]');
ylabel('Energy [J]');

%% Energy losses
subplot(2,2,3);
plot(tout/unit("day"), D/unit("W"));
xlim([0 tout(end)/unit("day")]);
grid on;
title('Losses');
xlabel('Time [day]');
ylabel('Dissipation rate [W]');

%% Load balancing
disp(exist('PSell','var'))
disp(exist('PBuy','var'))

subplot(2,2,4);
plot(tout/unit("day"), PSell/unit("W"));
hold on;
plot(tout/unit("day"), PBuy/unit("W"));
xlim([0 tout(end)/unit("day")]);
grid on;
title('Load balancing');
xlabel('Time [day]');
ylabel('Power [W]');
legend("Sell","Buy");

%% Pie charts

% Integrate power signals in time
EfromSupplyTransport = trapz(tout, PfromSupplyTransport);
EtoDemandTransport   = trapz(tout, PtoDemandTransport);

ESell = trapz(tout, PSell);
EBuy  = trapz(tout, PBuy);

% Sorption storage
EtoInjection    = trapz(tout, PtoInjection);
EfromExtraction = trapz(tout, PfromExtraction);

% Battery storage
EtoBattery      = trapz(tout, PtoBatteryInjection);
EfromBattery    = trapz(tout, PfromExtractionBattery);

% Storage dissipation
EStorageDissipation = trapz(tout, DStorage);

% Direct supply-to-demand energy
EDirect = EfromSupplyTransport ...
    - ESell ...
    - EtoInjection ...
    - EtoBattery;

figure;
tiles = tiledlayout(1,2);

%% Received energy breakdown
ax = nexttile;

pie(ax,...
    [EDirect,...
    EtoInjection,...
    EtoBattery,...
    ESell] ./ EfromSupplyTransport);

lgd = legend({ ...
    'Direct to demand', ...
    'To sorption storage', ...
    'To battery', ...
    'Sold'});
lgd.Layout.Tile = 'south';

title(sprintf( ...
    'Received energy %.2e [J]', ...
    EfromSupplyTransport/unit('J')));

%% Delivered energy breakdown
ax = nexttile;

pie(ax,...
    [EDirect,...
    EfromExtraction,...
    EfromBattery,...
    EBuy] ./ EtoDemandTransport);

lgd = legend({ ...
    'Direct from supply', ...
    'From sorption storage', ...
    'From battery', ...
    'Bought'});
lgd.Layout.Tile = 'south';

title(sprintf( ...
    'Delivered energy %.2e [J]', ...
    EtoDemandTransport/unit('J')));

%% Battery diagnostics

fprintf('\nBattery Energy Summary:\n');
fprintf('Charged into battery:     %.3e J\n', EtoBattery);
fprintf('Discharged from battery:  %.3e J\n', EfromBattery);

figure;
plot(tout/unit("day"), PfromExtractionBattery);
grid on;
title('Battery Discharge Power');
xlabel('Time [day]');
ylabel('Power [W]');

figure;

plot(tout/unit("day"), EStorageBattery/unit("kWh"), 'LineWidth', 1.5);
hold on;

yline(EBatteryMin/unit("kWh"), '--r', 'Battery Min');
yline(EBatteryMax/unit("kWh"), '--g', 'Battery Max');

grid on;
title('Battery Stored Energy');
xlabel('Time [day]');
ylabel('Energy [kWh]');

legend('Battery Energy','Min Limit','Max Limit');

fprintf('\nBattery Statistics:\n');
fprintf('Initial: %.2f kWh\n', EStorageBattery(1)/unit("kWh"));
fprintf('Maximum: %.2f kWh\n', max(EStorageBattery)/unit("kWh"));
fprintf('Minimum: %.2f kWh\n', min(EStorageBattery)/unit("kWh"));
fprintf('Final:   %.2f kWh\n', EStorageBattery(end)/unit("kWh"));

figure

plot(tout/unit("day"), EStorageBattery/unit("kWh"))
hold on
plot(tout/unit("day"), EStorage/unit("kWh"))

grid on

legend('Battery','Sorption')
xlabel('Time [day]')
ylabel('Energy [kWh]')

figure
plot(tout/unit("day"), EStorageBattery/unit("kWh"))
xlim([150 157])   % any 7-day window
grid on