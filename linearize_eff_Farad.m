function [coeffs2, error, relative_error] = linearize_eff_Farad(jmin, jmax, Tmin, Tmax, eff_Farad, num_segments, Tstep, figures)
% Function carries out a piecewise linearization of a eff_Farad curve as a
% function of temperature and current density. Input parameters are the
% boundaries of the temperature and current density range, a matrix with
% the eff_Farad values where each row is different current density and each
% column is a different temperature, the number of segments (assumed to be
% the same in both x and y direction) 
% 'AWE'/'PEM'/'SOEC' (used for naming the csv files)

% The output is a matrix with coefficients where:
% the linearized eff_Farad = a + b*T + c*j
%  a in the first column
%  b in the second column
%  c in the third column
% Each row is a segment, the first num_segments rows are the first
% temperature segment and ascending all different current density segments, the second 
% num_segments rows are the second temperature segment and ascending all
% different current density segments and so on




% notities voor jezelf:
% Voor segment_length heb je floor gebruikt, hierdoor is het mogelijk dat
% num_segments*segment_length < length(Trange). Hierdoor wordt er mogelijks
% een klein extra segmentje te veel gemaakt op het einde waardoor er een
% extra start en end is. om dit tegen te gaan gebruik je in segment_ends
% segment_starts(2:end-1) en de laatste waarde van de starts wordt niet
% gebruikt omdat dit mogelijks de start is van dat extra segmentje, in
% plaats daarvan gebruik je sws de lengte en verwijder je dat laatste elementje in de starts omdat
% dat dus van dat kleine extra segmentje is, hierdoor kan je laatste
% segment dus langer zijn dan de andere!

Trange = Tmin:Tstep:Tmax; %K
jrange = jmin:(jmax-jmin)/((Tmax-Tmin)/Tstep):jmax; %A/m²%A/m² Both Trange and jrange have the same length!
segment_length = floor(length(Trange)/num_segments);
num_long_segments = rem(length(Trange), num_segments); %aantal segmenten dat met 1 verlengd moet worden

segment_starts = [1 cumsum(repmat(segment_length,1,num_segments-1))+1];
segment_ends = [cumsum(repmat(segment_length,1,num_segments-1)) length(Trange)];

if num_long_segments > 0
    for i = 1:num_long_segments
        segment_ends(i) = segment_ends(i) + 1;
        segment_starts(i+1:end) = segment_starts(i+1:end) + 1;
        segment_ends(i+1:end) = segment_ends(i+1:end) + 1;
    end
end

if segment_ends(end) > length(Trange)
    segment_ends(end) = length(Trange);
end


% eff_Farad: different rows are different values for current, different
% columns are different values for temperature
% eff_Farad matrix to vector so we can use it for function regress

% two long vectors for temp and current density so one can just iterate
% over these vectors with same index to have all possible combinations of temp and current
% density, necessary for regress



% Linear regression for each segment individually, so you need a Tvector
% and j vector for each segment separately
% (niet werken met segment_length maar end-start voor variabele lengte laatste segment)
% Deze vectoren mogen dan gwn vergeten worden als je naar de volgende
% segmentloop gaat 
coeffs2 = zeros(num_segments^2,3); 
% coefficienten worden weggeschreven in coeffs2 op de volgende manier:
% eerste num_segment rijen zijn telkens de 3 coefficienten voor 1 bepaald
% temperatuurssegment en oplopende stroomsegmenten, de volgende num_segment
% zijn de coefficienten voor het volgende temperatuurssegment voor alle
% stroomsegmenten
eff_Faradtest2 = zeros(size(eff_Farad));
for seg_idxT = 1:num_segments
    for seg_idxJ = 1:num_segments
        % voor lengte niet met kwadraat werken maar lengte T maal lengte J
        % zodat je ook kunt werken met vectoren voor wanneer vb 1e segment
        % van T en laatste segment van j
        Tvector2 = zeros((segment_ends(seg_idxT)-segment_starts(seg_idxT)+1)*(segment_ends(seg_idxJ)-segment_starts(seg_idxJ)+1),1); %iedere keer opnieuw gedefinieerd want lengte laatste segment kan verschillen
        jvector2 = zeros((segment_ends(seg_idxT)-segment_starts(seg_idxT)+1)*(segment_ends(seg_idxJ)-segment_starts(seg_idxJ)+1),1);
        eff_Faradvector2 = zeros((segment_ends(seg_idxT)-segment_starts(seg_idxT)+1)*(segment_ends(seg_idxJ)-segment_starts(seg_idxJ)+1),1);
        % end-start ipv length omdat laatste segment langer kan zijn dan
        % length
        % +1 omdat 50-1 = 49 maar toch 50 elementen
        
        % Voor regression moeten alle mogelijke combinaties van elementen
        % van vectoren expliciet op een rij gezet worden 
        % eg T = (1,2) j = (3,4) geeft 4 combinaties, maar voor regression
        % te doen werken moet je volgende vectoren maken:
        % Tvector = (1,1,2,2) jvector = (3,4,3,4) zodat je alle punten hebt
        % als je gwn beide vectoren overloopt van begin tot eind met zelfde
        % index
        for i = segment_starts(seg_idxT):segment_ends(seg_idxT)
            for j = segment_starts(seg_idxJ):segment_ends(seg_idxJ)
                %(segment_ends(seg_idxJ)-segment_starts(seg_idxJ)+1) en
                %niet length(Trange) omdat voor laatste T segment worden
                %steeds verschillende j segmenten overlopen met lengte
                %groter dan length(Trange)
                Tvector2((i-segment_starts(seg_idxT))*(segment_ends(seg_idxJ)-segment_starts(seg_idxJ)+1)+(j-segment_starts(seg_idxJ)+1)) = Trange(i); 
                jvector2((i-segment_starts(seg_idxT))*(segment_ends(seg_idxJ)-segment_starts(seg_idxJ)+1)+(j-segment_starts(seg_idxJ)+1)) = jrange(j);
                eff_Faradvector2((i-segment_starts(seg_idxT))*(segment_ends(seg_idxJ)-segment_starts(seg_idxJ)+1)+(j-segment_starts(seg_idxJ)+1)) = eff_Farad(j,i);
            end 
        end
       
        X = [ones(size(Tvector2)) Tvector2 jvector2]; %bedoeling dat dit 3 kolommen zijn van length(Trange) rijen 
        % Coefficients are allocated in coeffs2 in the following way:
        % Each row contains the information for one segment, 
        % eff_Farad = coeffs2(rownumber, 1) + coeffs2(rownumber, 2)*Tvector2 +
        % coeffs2(rownumber, 3)*jvector2
        coeffs2(seg_idxJ + (seg_idxT-1)*num_segments, 1:3) = regress(eff_Faradvector2, X)'; % moest je nog iets veranderen is num_segmetns hier number of segments van J
        % regress makes use of ordinary least square method (OLS) for
        % linear regression (says ChatGPT)
        
        for i = segment_starts(seg_idxT):segment_ends(seg_idxT)
            for j = segment_starts(seg_idxJ):segment_ends(seg_idxJ)
                eff_Faradtest2(j,i) = coeffs2(seg_idxJ + (seg_idxT-1)*num_segments,1) + Trange(i)*coeffs2(seg_idxJ + (seg_idxT-1)*num_segments,2) + jrange(j)*coeffs2(seg_idxJ + (seg_idxT-1)*num_segments,3);
            end
        end
    end
end



if figures
    figure(41)
    h =surf(Trange-273, jrange, eff_Faradtest2, 'EdgeColor',[0 0 0]);
    xlabel("Temperature [°C]", FontSize=10)
    ylabel("Current density [A/m²]",FontSize=10)
    zlabel("eff_{Farad}",FontSize=10)
    set(h,'LineStyle','none')
    title(append("Linearized eff_{Farad} curve ",string(num_segments), " segments"))
    view(30,40)
    grid on
    xh = get(gca,'XLabel'); % Handle of the x label
    set(xh, 'Units', 'Normalized')
    pos = get(xh, 'Position');
    set(xh, 'Position',pos.*[1,-0.0,1],'Rotation',-10)
    yh = get(gca,'YLabel'); % Handle of the y label
    set(yh, 'Units', 'Normalized')
    pos = get(yh, 'Position');
    set(yh, 'Position',pos.*[1.12,-0.7,1],'Rotation',40)

    % Plotting black lines at border of each segment
    hold on
    for seg_idxj = 1:num_segments-1
        for i = 1 : length(Trange)
            jline(i) = jrange(segment_ends(seg_idxj));
            Pline(i) = eff_Farad(segment_ends(seg_idxj),i);
        end
        line(Trange(:)-273, jline, Pline,'Color', 'black');
    end
    
    for seg_idxT = 1:num_segments-1  
        for i = 1 : length(Trange)
                Tline(i) = Trange(segment_ends(seg_idxT));
                Pline(i) = eff_Farad(i,segment_ends(seg_idxT));
         end
         line(Tline-273, jrange(:), Pline,'Color', 'black');
    
    end
    hold off
end

%% Writing the coefficients to a csv file with appropriate name
filename = append('C:\Users\matth\Documents\IW5\Thesis\JULIA\','coeffs_eff_Farad',string(num_segments),'.csv');
% delete the existing file if it exists
if exist(filename, 'file')
    delete(filename);
end
% Open the CSV file for writing
fileID = fopen(filename, 'w');
% Write the headers to the CSV file
fprintf(fileID, 'Coefficients constant [-],Coefficients T [1/K],Coefficients j [1/(A/m^2)]\n');
% Write the data to the CSV file
for i = 1:num_segments^2
    fprintf(fileID, '%f, %f, %f\n', coeffs2(i,:).');
end
% Close the CSV file
fclose(fileID);


%% Figure difference between given non-linear eff_Farad curve and linearized eff_Farad
if figures
    figure(42)
    h =surf(Trange-273, jrange, (eff_Farad - eff_Faradtest2)./eff_Farad, 'EdgeColor','none');
    xlabel("Temperature [°C]", FontSize=10)
    ylabel("Current density [A/m²]",FontSize=10)
    zlabel("\eta_{Farad, Lin} - \eta_{Farad})/\eta_{Farad} [-]",FontSize=10)
    set(h,'LineStyle','none')
    title(append("Relative linearization error on Faraday efficiency with ",string(num_segments), " segments"))
    view(30,40)
    grid on
    xh = get(gca,'XLabel'); % Handle of the x label
    set(xh, 'Units', 'Normalized')
    pos = get(xh, 'Position');
    set(xh, 'Position',pos.*[1,-0.0,1],'Rotation',-10)
    yh = get(gca,'YLabel'); % Handle of the y label
    set(yh, 'Units', 'Normalized')
    pos = get(yh, 'Position');
    set(yh, 'Position',pos.*[1.12,-0.7,1],'Rotation',40)
end

%% Calculating mean error
error = 0;
relative_error = 0;
for i =1:length(Trange)
    for j = 1:length(jrange)
        error = error + abs(eff_Farad(j,i) - eff_Faradtest2(j,i))/(length(Trange)*length(jrange)); 
        relative_error = relative_error + abs((eff_Farad(j,i) - eff_Faradtest2(j,i))/eff_Farad(j,i))/(length(Trange)*length(jrange));
    end 
end
