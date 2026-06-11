set(groot, 'defaultAxesFontSize', 18);
set(groot, 'defaultLegendFontSize', 18);
% ==========================================
% --- 1. DATA IMPORT & PREPARATION ---
% ==========================================
data = readtable("log2.txt");
masss = data{:, 1};
temp = data{:, 3}; % Extract the 3rd column for Temperature
% Process the mass data
masss = masss - 556.25;%Reactor weight
% First, slice out the giant sensor errors
cleanmass = filloutliers(masss, 'center', 'movmedian', 300);
% Second, smooth out the micro-jitter for the whole dataset
smoothMass = smoothdata(cleanmass, 'gaussian', 500); 

% ==========================================
% --- SORPTION RATIO (X) CONVERSION ---
% ==========================================
X_0 = 0.40; % Maximum initial capacity (40% = 0.40 kg_water / kg_dry_gel)
% Assume the experiment starts at full saturation since water is vaporizing out
m_initial = smoothMass(1); 
m_dry = m_initial / (1 + X_0); % Calculate the invariant dry mass of silica gel
% Convert the absolute mass vector into the uptake ratio X(t)
X_history = (smoothMass - m_dry) / m_dry;

% ==========================================
% --- 2. SMART TEMPERATURE FIX ---
% ==========================================
error_val = 90; 
error_val_min = 20; 
capping_val = error_val; 
for n = 1:length(temp)
    if temp(n) >= error_val || temp(n) <= error_val_min 
        if n > 1
            capping_val = temp(n-1); 
        else
            capping_val = temp(n);   
        end
        break; 
    end
end
temp(temp > error_val | temp < error_val_min) = capping_val;
temp = fillmissing(temp, 'previous');
time = (0:length(cleanmass)-1) * 2;

% ==========================================
% --- CUSTOM COLORS ---
% ==========================================
% Define exact RGB triplets [R, G, B] for lighter, softer colors
lightBlue   = [0.35, 0.65, 0.90]; 
lightOrange = [0.95, 0.55, 0.20];

% ==========================================
% --- FIGURE 1: FULL DURATION (RATIO X) ---
% ==========================================
figure(1); clf;
ax = gca; % Get current axes

yyaxis left;
ax.YColor = lightBlue; % Force the left axis color
plot(time, X_history, 'Color', lightBlue, 'LineWidth', 2);  
ylabel('Uptake Ratio X (kg_{water} / kg_{dry gel})');

yyaxis right;
ax.YColor = lightOrange; % Force the right axis color
plot(time, temp, 'Color', lightOrange, 'LineWidth', 1.5);
ylabel('Temperature (°C)');

title('Full Experiment: Uptake Ratio (X) and Temperature Over Time');
xlabel('Time (seconds)');
legend('Sorption Ratio (X)', 'Temperature', 'Location', 'best');

% ==========================================
% --- REVISED 4. FIND STEADY STATE ---
% ==========================================
window_points = 150; 
X_tolerance = 0.001; %so if the change is less than 0.1% we are done

for i = (window_points + 1):length(X_history)
    past_5_mins = X_history(i - window_points : i);
    fluctuation = max(past_5_mins) - min(past_5_mins);
    
    if fluctuation <= X_tolerance
        steady_index = i;
        steady_time = time(steady_index);
        steady_X = X_history(steady_index);
        fprintf('Steady state reached at %d seconds (X: %.4f kg/kg)!\n', steady_time, steady_X);
        break; 
    end
end

if exist('steady_time', 'var') && ~isnan(steady_time)
    figure(1); 
    hold on;   
    xline(steady_time, '--g', 'Steady State Reached', 'LabelVerticalAlignment', 'bottom', 'FontSize', 18, 'HandleVisibility', 'off');
end

% ==========================================
% --- 5. CALCULATE RATE OF CHANGE (dX/dt) ---
% ==========================================
dXdt = gradient(X_history, time);
smooth_dXdt = smoothdata(dXdt, 'gaussian', 30);

% ==========================================
% --- FIGURE 3: RATE OF CHANGE (dX/dt) & TEMPERATURE ---
% ==========================================
figure(3); clf;
ax = gca;

yyaxis left;
ax.YColor = 'm'; 
plot(time, smooth_dXdt, 'm', 'LineWidth', 2); 
hold on;
yline(0, '--k', 'LineWidth', 1.5); 
ylabel('dX/dt (kg_{water} / kg_{dry gel} \cdot s)');

yyaxis right;
ax.YColor = lightOrange; % Match your light orange
plot(time, temp, 'Color', lightOrange, 'LineWidth', 1.5);
ylabel('Temperature (°C)');

if exist('steady_time', 'var') && ~isnan(steady_time)
    xline(steady_time, '--g', 'Steady State Reached', 'LabelVerticalAlignment', 'bottom', 'FontSize', 18, 'HandleVisibility', 'off');
end

title('Sorption Kinetics: Rate of Change (dX/dt) and Temperature');
xlabel('Time (seconds)');
legend('dX/dt Rate', 'Zero Rate', 'Temperature', 'Location', 'northeast');

% ==========================================
% --- FIGURE 5: MASS & TEMPERATURE OVER TIME ---
% ==========================================
figure(5); clf;
ax = gca;

yyaxis left;
ax.YColor = lightBlue; 
plot(time, smoothMass, 'Color', lightBlue, 'LineWidth', 2); 
ylabel('Absolute Mass (g)'); 

yyaxis right;
ax.YColor = lightOrange; 
plot(time, temp, 'Color', lightOrange, 'LineWidth', 1.5);
ylabel('Temperature (°C)');


if exist('steady_time', 'var') && ~isnan(steady_time)
    xline(steady_time, '--g', 'Steady State Reached', ...
        'LabelVerticalAlignment', 'bottom', 'FontSize', 18, 'HandleVisibility', 'off');
end

title('Absolute Mass and Temperature Over Time');
xlabel('Time (seconds)');
legend('Absolute Mass', 'Temperature', 'Location', 'northeast');

% ==========================================
% --- FIGURE 6: RATE OF MASS CHANGE (dM/dt) ---
% ==========================================
% Calculate the rate of change of the absolute mass
dMdt = gradient(smoothMass, time);
smooth_dMdt = smoothdata(dMdt, 'gaussian', 30);

figure(6); clf;
ax = gca;

% Plot dM/dt on the left axis
yyaxis left;
ax.YColor = 'm'; 
plot(time, smooth_dMdt, 'm', 'LineWidth', 2); 
hold on;
yline(0, '--k', 'LineWidth', 1.5); 
ylabel('Rate of Mass Change dM/dt (g/s)'); 

yyaxis right;
ax.YColor = lightOrange;
plot(time, temp, 'Color', lightOrange, 'LineWidth', 1.5);
ylabel('Temperature (°C)');

if exist('steady_time', 'var') && ~isnan(steady_time)
    xline(steady_time, '--g', 'Steady State Reached', ...
        'LabelVerticalAlignment', 'bottom', 'FontSize', 18, 'HandleVisibility', 'off');
end

title('Rate of Mass Change (dM/dt) and Temperature');
xlabel('Time (seconds)');

% Add the legend in the top right corner
legend('dM/dt Rate', 'Zero Rate', 'Temperature', 'Location', 'northeast');

% ==========================================
% ---  k VALUE over the curse of the whole expriemnt ---
% ==========================================
Start=275;%Start and the end values for the finding k it is need because some experiments have faulty data which deviates it quit a lot
End=400;
Start=Start/2;
End=End/2;
X_region    = X_history(Start:End);
dXdt_region = smooth_dXdt(Start:End);
k_vector = dXdt_region ./ (steady_X - X_region);
k_vector = k_vector(isfinite(k_vector));
k_est = mean(k_vector);

fprintf('\n=== KINETICS VALIDATION ===\n');
fprintf('Evaluated Region: Indices %d to %d\n', start, endv);
fprintf('Estimated k Constant: %.6e 1/s\n', k_est);

% ==========================================
% --- 7. SIMULATION VS REAL & COMPARISON ---
% ==========================================
model_name = 'Validation_sim'; 
if extractBefore(string(which(model_name)), '.slx') == ""
    error('The model file "%s.slx" was not found in the current folder or MATLAB path.', model_name);
end

% --- SIMULINK COMPATIBILITY PREPARATION ---
t_end = time(end);
k_est_feed = [ [0; t_end], [k_est; k_est] ];
steady_X_feed = [ [0; t_end], [steady_X; steady_X] ];

fprintf('\n=== AUTOMATIC MODEL SIMULATION ===\n');
fprintf('Launching Simulink model "%s" dynamically...\n', model_name);
out = sim(model_name, ...
          'StopTime', num2str(t_end), ...
          'SrcWorkspace', 'current');
fprintf('Simulation complete! Processing results...\n');

if ~isprop(out, 'X_sim')
    error('Simulink ran successfully, but "out.X_sim" was not found.');
end

simTime = out.X_sim.Time;
X_sim   = out.X_sim.Data;

% --- FIGURE 4: EXPERIMENTAL VS SIMULINK ---
figure(4); clf;
plot(time, X_history, 'Color', lightBlue, 'LineWidth', 2); 
hold on;
plot(simTime, X_sim, 'r--', 'LineWidth', 2); 
grid on;

if exist('steady_time', 'var') && ~isnan(steady_time)
    xline(steady_time, '--g', 'Steady State Reached', ...
        'LabelVerticalAlignment', 'bottom', 'FontSize', 18, 'HandleVisibility', 'off');
end

title('Model Validation: Experimental vs. Simulink Uptake Ratio');
xlabel('Time (seconds)');
ylabel('Uptake Ratio X (kg_{water} / kg_{dry gel})');
legend('Experimental Data (X_{exp})', 'Simulink Model (X_{sim})', 'Location', 'best');

% --- ERROR ANALYSIS ---
X_sim_interp = interp1(simTime, X_sim, time, 'linear', 'extrap');
if size(X_sim_interp, 1) ~= size(X_history, 1)
    X_sim_interp = X_sim_interp';
end
rmse = sqrt(mean((X_history - X_sim_interp).^2, 'omitnan'));

fprintf('\n=== SIMULINK VALIDATION METRICS ===\n');
fprintf('Simulation Duration: %.1f seconds\n', t_end);
fprintf('Root Mean Squared Error (RMSE): %.5f kg/kg\n', rmse);

if rmse < 0.01
    fprintf('Status: Excellent model agreement!\n');
elseif rmse < 0.04
    fprintf('Status: Acceptable agreement. Check for slight thermal delays.\n');
else
    fprintf('Status: High deviation. Consider tuning your parameters.\n');
end