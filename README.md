\documentclass{article}
\usepackage{graphicx}
\usepackage[most]{tcolorbox} % Added for custom instruction boxes
\usepackage{fancyhdr} % Added for header/footer commands
\usepackage{float}
% Define the custom \instruction command
\newcommand{\instruction}[1]{
    \begin{tcolorbox}[
        colback=blue!5!white,      % Light blue background
        colframe=blue!75!black,    % Dark blue frame
        title=Instruction,         % Title of the box
        fonttitle=\bfseries,       % Bold title font
        arc=2mm,                   % Rounded corners
        boxrule=0.5pt,             % Thickness of the frame
        left=2mm, right=2mm, top=2mm, bottom=2mm, % Padding
        fontupper=\small\itshape   % Make the text small and italic
    ]
        #1
    \end{tcolorbox}
}

\title{SSA6}
\author{Maksim Pirozhenko}
\date{June 2026}

\begin{document}
\maketitle

\section{Introduction}
The goal of this SSA is to perform the whole validation part of our experiment, including an explanation of the experimental setup 
\section{Future Steps}
The last section needs to be written down, and the current first 2 sections' drafts also have to be finished\\
Bibliography(!!!)\\
Decide on whether to keep or not the 3RD DHT sensor on our schematics(we are not using it in the experiment)\\
Decide whether to add or not the argument on how it could have been done better (Like finding E ourselves)\\
Write the Validation of the D-A equation, since currently the $X_{eq}$ is being found differently(maybe proving E that way)
\section{Conclusion}
The whole SSA follows the same structure as the report
Starting from the experimental definition, going through the results of the experiment, and going to the system scale validation(the one I haven't written yet)
and thus no conclusion
\section{Problems}
I was struggling to find the exact formulas from the SSAs, so I had to extract them from the Simulink code directly, thus they might or might not have different names\\
I was really low on time when writing this SSA, so some sections are in a very early draft version for a report and need to be clarified and refined(sorry)\\
\newpage
\section{Model validation}
\lhead{Reflection} % section header

\subsection{Lab-scale validation experiment}
\instruction{In this section, you describe the lab-scale validation experiment for a physical law of relevance to the real-world EST system. You discuss the assumptions underlying this physical law with support of scientific literature (including references) and present a theoretical prediction (i.e., an equation relating two or more variables). Include a picture and schematic of your experiment. Max 300 words.}
There are two physical laws explicitly used in our EST model:$$\frac{dX}{dt} = k_{Ldf}(X_{eq} - X)$$where $X_{eq}$ is defined as the equilibrium uptake ratio of the silica at a given temperature and vapor pressure (e.g., at $67^\circ\text{C}$ and ambient humidity, the mass of the water stored inside the silica equates to $14\%$ of the dry silica mass itself). This theoretical limit is calculated using the Dubinin-Astakhov (D-A) Isotherm for thermodynamic equilibrium:$$X_{eq} = X_0 \exp\left(-\left(\frac{RT}{E}\ln\left(\frac{p_{sat}}{p_v}\right)\right)^n\right)$$
These equations feature multiple unknown values that we are unable to find, that can not be found unfortunately:(cause you guys kept giving us faulty sensors)
First, the $X_0$ value representing the total absorption ratio of the silica, to find this value, the silica needs to be completely dried up at around 120-150 degrees Celsius \\
The second value $E$ represnts Characteristic Energy of Adsorption of the silica gel. This value could theoretically be found by performing an experiment and finding $X_{eq}$ at different temperatures, and by transforming the equation to solve for E 
\subsection{Experimental Setup}
Our experimental setup has the goal of tracking the change of the mass ($\frac{dX}{dt}$) with the calibrated HX711 load cell, and the temperature of the silica for the D-A equation to find $X_{eq}$.To find the $p_v$, we use the formula :$$p_v = p_{sat}(T_{lab}) \times \text{RH}$$For $T_{lab}$, we use the value of the external DHT22 sensor located outside of the capsule. From the same sensor, we take the value for the relative humidity (Kinda a lie because we forgot to take it, but we can just use a regular value for the relative humidity inside the buildings). The $T$ is the temperature of the inside of the silica and is being taken from the internal DHT22 sensor (middle). Importantly, we also measure the mass of the empty silica reactor prior to experiment to shift mass data later on

\subsubsection{Sensors Used}
\textbf{Calibrated HX711 Load Cell}: Used to track the change of the mass of the silica over time ($\frac{dX}{dt}$).\\
\textbf{External DHT22 Sensor(bottom)}: Located outside the capsule. Used to get the $T_{lab}$ and the relative humidity to calculate the vapor pressure ($p_v$).\\
\textbf{Internal DHT22 Sensor (top)}: Located in the middle of the silica. Used to get the internal temperature ($T$) needed for the D-A equation.
\begin{figure}[H]
    \centering
    \includegraphics[width=1\linewidth]{EST schematics.png}
    \caption{Circuitry}
    \label{fig:placeholder}
\end{figure}
\subsection{Lab-scale validation results}
\instruction{In this section, you present the results of your validation experiment using figures that provide insight into the quality of the experimental data (e.g., using error bars). You must also compare the prediction by the theoretical physical law to the experimental results and provide an interpretation of the similarities and differences. Use at most 3 figures. Max 300 words.}
After performing the experiment and plotting the data, the following graphs were obtained for the temperature. The temperature sensor was capped at the last reasonable reading to prevent it since it was returning unrealistic values(e.g., $125 C \circ$ or $-60 C \circ$) when overheated(we could've prevented that by drying the silica at a much lower temperature, but it is what it is now). Also, the mass default filtering function from MATLAB was used, as well as the special function to neglect faulty readings. (filloutliers)
\begin{figure}[H]
    \centering
    \includegraphics[width=1.25\linewidth]{image.png}
    \caption{Primary data from the experiment}
    \label{fig:placeholder}
\end{figure}
To find the value of $X_{eq}$, the weight history was implemented, setting that if the mass has not changed by more than 5 g over a course of 5 minutes, it can be stated that $X_{eq}$ has been reached. This happens after drying for around 15 minutes(892 seconds), and the mass is $\approx 189 g$ by using the absorption rate gel at the room temperature to be 40 percent the $X_{eq}=0.2307 kg/kg$ water per seilca ratio(or 23 percent)), by checking the drying rate at its peak of $-0.08 g/s$
At 446 seconds, the ratio $X$ based on \ref{fig:placeholder} is $0.31 kg/kg$(31 percent) so the k value is $k_{Ldf} \approx 0.00667 \text{ s}^{-1}$
\begin{figure}[H]
    \centering
    \includegraphics[width=0.75\linewidth]{Dxdt.png}
    \caption{dX/dt}
    \label{fig:rate}
\end{figure}

\subsection{System-scale validation}
\instruction{In this section, you discuss the impact of the scale difference between the lab experiment and the real system. Using dimensionless numbers where appropriate, you discuss the anticipated modeling errors at the system scale qualitatively and quantitatively. You also reflect upon the capabilities and limitations of the Simulink model, identify critical model components, and state recommendations for improvement. Max 300 words.}
This part I haven't written yet
\end{document}
