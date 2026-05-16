% Post-processing script for the EST Simulink model. This script is invoked
% after the Simulink model is finished running (stopFcn callback function).

close all;
figure;

%% Supply and demand
subplot(2,2,1);
plot(tout/unit("month"), PSupply/unit("kW"));
hold on;
plot(tout/unit("month"), PDemand/unit("kW"));
xlim([0 tout(end)/unit("year")]);
grid on;
title('Supply and demand');
xlabel('Time [month]');
ylabel('Power [W]');
legend("Supply","Demand");


%% Stored energy
subplot(2,2,2);
plot(tout/unit("month"), EStorage/unit("kWh"));
xlim([0 tout(end)/unit("year")]);
grid on;
title('Storage');
xlabel('Time [month]');
ylabel('Energy [kWhJ]');

%% Energy losses
subplot(2,2,3);
plot(tout/unit("month"), D/unit("W"));
xlim([0 tout(end)/unit("year")]);
grid on;
title('Losses');
xlabel('Time [month]');
ylabel('Dissipation rate [W]');

%% Load balancing
subplot(2,2,4);
plot(tout/unit("month"), PSell/unit("kW"));
hold on;
plot(tout/unit("month"), PBuy/unit("kW"));
xlim([0 tout(end)/unit("year")]);
grid on;
title('Load balancing');
xlabel('Time [month]');
ylabel('Power [W]');
legend("Sell","Buy");
% 1. Open a new figure window
figure;

sec_per_month = 30 * 24 * 3600;
target_times = (1:12) * sec_per_month;

CumulativeSupply_J = cumtrapz(tout, PSupply);
CumulativeDemand_J = cumtrapz(tout, PDemand);

% 4. assume the value at the end of the month if it is not rperesented inn
% the table
cum_supply_at_months_J = interp1(tout, CumulativeSupply_J, target_times);
cum_demand_at_months_J = interp1(tout, CumulativeDemand_J, target_times); 

% Convert the monthly checkpoints to kWh
cum_supply_at_months_kWh = cum_supply_at_months_J / unit("kWh");
cum_demand_at_months_kWh = cum_demand_at_months_J / unit("kWh"); 

% 5. Calculate the energy DURING each month
monthly_produced_kWh = diff([0, cum_supply_at_months_kWh]);
monthly_consumed_kWh = diff([0, cum_demand_at_months_kWh]); 

% 6. Calculate the Surplus/Dificit (Produced + Consumed)
monthly_total_kWh = monthly_produced_kWh - monthly_consumed_kWh;



% Top Plot: Produced vs Consumed (Side-by-Side Bars)
subplot(2,1,1);

bar_data = [monthly_produced_kWh(:), monthly_consumed_kWh(:)]; 
bar(1:12, bar_data);

grid on;
title('Energy Produced vs. Consumed PER Month');
xlabel('Month');
ylabel('Energy [kWh]');
legend('Produced (Supply)', 'Consumed (Demand)', 'Location', 'best');
xticks(1:12);

% Bottom Plot: Total Energy Surplus
subplot(2,1,2);
bar(1:12, monthly_total_kWh, 'FaceColor', [0.5 0.3 0.7]);
grid on;
title('Total Energy Surplus in a month')
%% Pie charts

% integrate the power signals in time
EfromSupplyTransport = trapz(tout, PfromSupplyTransport);
EtoDemandTransport   = trapz(tout, PtoDemandTransport);
ESell                = trapz(tout, PSell);
EBuy                 = trapz(tout, PBuy);
EtoInjection         = trapz(tout, PtoInjection);
EfromExtraction      = trapz(tout, PfromExtraction);
EStorageDissipation  = trapz(tout, DStorage);
EDirect              = EfromSupplyTransport - ESell - EtoInjection;
ESurplus             = EtoInjection-EfromExtraction-EStorageDissipation;

figure;
tiles = tiledlayout(1,2);

ax = nexttile;
pie(ax, [EDirect, EtoInjection, ESell]/EfromSupplyTransport);
lgd = legend({"Direct to demand", "To storage", "Sold"});
lgd.Layout.Tile = "south";
title(sprintf("Received energy %3.2e [J]", EfromSupplyTransport/unit('J')));

ax = nexttile;
pie(ax, [EDirect, EfromExtraction, EBuy]/EtoDemandTransport);
lgd = legend({"Direct from supply", "From storage", "Bought"});
lgd.Layout.Tile = "south";
title(sprintf("Delivered energy %3.2e [J]", EtoDemandTransport/unit('J')));