for w = 1:15


N=600;   % no of sensors
M=50;    % no of locations
T=6400;    %total time taken
Rm=30;   % radius of sink
time=T;
x=randi([0,100],1,N); % x co-ordinate of sensors
y=randi([0,100],1,N); % y co-ordinate of sensors
a=randi([0,100],1,M); % x co-ordinate of locations
b=randi([0,100],1,M); % y co-ordinate of locations
energy=randi([5,15],1,N); % energy content of sensors
vel = 2;              % speed of mobile sink
dgr=1;                % data generation rate per unit time
ec = zeros(1,N);      % energy consumption rate per unit length of data
beta = 0.05;
gamma = 2;            % gamma ranges between 2 & 4
ehr=0.5;              % energy harvested per unit time
capacity=1000;          % energy capacity
Total_data = T * N * dgr;
mobile_data = 0;      % data collected by sink

%survival_time = zeros(1,N);    % array to store survival time of the sensors.
%data = zeros(1,N);             % array to store amount of data generated by sensors
cluster_data = zeros(1,M);      % array to store data offered by each cluster
sojourn_time = zeros(1,M);      % array to store sojourn time of each location

sensor_pos = [x' y'];       %% sensor postion matrix (N X 2)
locations = [a' b'];        %% location matrix (M X 2)
clusters = zeros(1,N);         %% array to associated with appropriate location


%% making the clusters....

[clusters] = make_cluster( N , sensor_pos , M , locations , Rm , clusters);

%% determining the energy consumption rates for each sensor based on its distance from its cluster head...

for i=1:N
    if(clusters(1,i) == 0)
        ec(1,i) = 0.1;
        continue;
    end
    loc_x = locations(clusters(1,i) , 1);
    loc_y = locations(clusters(1,i) , 2);
    sen_x = sensor_pos(i,1);
    sen_y = sensor_pos(i,2);
    len = sqrt((loc_x-sen_x)*(loc_x-sen_x) + (loc_y-sen_y)*(loc_y-sen_y));
    ec(1,i) = 0.1 + 0.002*(len)^gamma;
end

%% plotting cluster network
%{
figure;
hold on
plot (x,y,'b*');
plot (a,b,'ro');
for i = 1:N
    clstr_head = clusters(1,i);
    if( clstr_head ~= 0 )
        p = locations(clstr_head , 1);
        q = locations(clstr_head , 2);
        r = sensor_pos(i , 1);
        s = sensor_pos(i , 2);
        plot([p,r],[q,s],'g-');
        hold on
    end
end
grid on;
hold off
%}

%% Constructing a matrix to calculate distances b/w each pair of locations...

dist = zeros(M,M);

for i = 1:M
    for j= (i+1):M
        x_distance = locations(i,1) - locations(j,1);
        y_distance = locations(i,2) - locations(j,2);
        dist(i,j) = sqrt( x_distance*x_distance + y_distance*y_distance);
        dist(j,i) = dist(i,j);
    end
end
clear x_distance;
clear y_distance;

%% making cluster sets....

cluster_set = zeros(M,N);
for i= 1:N
    if(clusters(1,i) ~= 0)
        cluster_set( clusters(1,i) , i) = 1;
    end
end

%% getting the starting point of our journey...

feasible_loc = 1:M;
survival_time = energy ./ (ec*dgr);
[index,mdata,cluster_data,sojourn_time,stoppage_time,energy] = get_first_index(feasible_loc,survival_time,sojourn_time,cluster_set,energy,cluster_data,dgr,M,N);

for i=1:N
    if( cluster_set(index,i) == 1)
        if(survival_time(1,i) >= stoppage_time)
            energy(1 , i) = energy(1 , i) - stoppage_time*dgr*ec(1,i);
            % display("energy " + i + " "+energy(1 , i));
        end
    end
end
% here, index represents our starting cluster_head...
trajectory = index;
mobile_data = mobile_data + mdata;

% updating energy after starting our journey....
for i=1:N
    energy(1,i) = min((energy(1,i) + ehr*stoppage_time),capacity);
end

survival_time = energy ./ (ec*dgr);
time = time - stoppage_time;

%% MAX_THROUGHPUT ALGORITHM

while(1)
    
    %% function to get a set of next feasible locations ...
    [feasible_loc] = get_next_feasible_loc(dist,trajectory,time,vel,M);
    
    %% now we will determine our next location from the set of feasible locations...
    if(feasible_loc ~= 0)
        %% determining our next sojourn location from a set of feasible locations...
        
        [index,mdata,cluster_data,sojourn_time,stoppage_time,energy] = get_Max_datagain_Index(trajectory,feasible_loc,survival_time,sojourn_time,cluster_set,energy,cluster_data,dgr,dist,vel,M,N);
        
        if((time - (dist(index,trajectory(end))/vel) - (dist(index,trajectory(1,1))/vel)) >= stoppage_time)
            %% harvesting energy of all sensors when sink travels to the index...        
            
            len = dist(index , trajectory(end));
            travel_time = len / vel;
            clear len;
            
            for i=1:N
                energy(1,i) = min((energy(1,i) + ehr*travel_time),capacity);
            end
            survival_time = energy ./ (ec*dgr);
            [d,s_time] = get_data_amount(N,trajectory(end),survival_time,cluster_set,dgr);
            
            if(d > mdata)
                index = trajectory(end);
                mdata = d;
                stoppage_time = s_time;
            else
                for i=1:N
                    energy(1,i) = min((energy(1,i) - ehr*travel_time),capacity);
                end
            end
            
            %% depleting the energy of sensors associated with data transmitting location...
            
            for i=1:N
                if( cluster_set(index,i) == 1)
                    if(survival_time(1,i) >= stoppage_time)
                        energy(1 , i) = energy(1 , i) - stoppage_time*dgr*ec(1,i);
                        display("energy " + i + " "+energy(1 , i));
                    end
                end
            end
                       
            
            %% adding our next location to trajectory...
            
            trajectory = [trajectory index];
            
            mobile_data = mobile_data + mdata;  % collecting data from location...
            
            % harvesting energy for all sensors...
            % energy reduction of sensors transmitting data is already done in getMaxIndex function...
            for i=1:N
                energy(1,i) = min((energy(1,i) + ehr*stoppage_time),capacity);
            end
            
            % determining survival time for each sensor based on their energy content...
            survival_time = energy ./ ec;
            survival_time = survival_time / dgr;
            
            % updating time left in the journey...
            time = time - travel_time - stoppage_time ;
            clear travel_time;
            
        else
            break;
        end
    end
end

%% LAST LOCATION ALGORITHM

%display("Trajectory before Last location :");
%display(trajectory(1,:) + " ");

if(time > (dist(trajectory(end),trajectory(1,1))/vel))
    % function to get a set of next feasible locations ...
    [feasible_last_loc] = get_last_feasible_loc(dist,trajectory,time,vel,M);
    
    survival_time = energy ./ (ec);
    survival_time = survival_time / dgr;
    
    [index,sojourn_time,mdata] = get_Last_Location_maxdatagain(feasible_last_loc,survival_time,cluster_set,dgr,M,N);
    
    if(index == trajectory(1,1))
        collection_time = time - (dist(trajectory(end),trajectory(1,1))/vel) ;
        trajectory = [trajectory index];
    else
        collection_time = time - (dist(trajectory(end),index)/vel) - (dist(index,trajectory(1,1))/vel);
        trajectory = [trajectory index];
        trajectory = [trajectory trajectory(1,1)];
    end
    
    if(sojourn_time > collection_time)
        sojourn_time = collection_time;
        time = 0;       % entire available collection time is utilised...
        mdata = 0;
        for s = 1:N
            if(cluster_set(index,s) == 1)
                mdata = mdata + max(survival_time(1,i) , sojourn_time)*dgr;
            end
        end
    else
        time = collection_time - sojourn_time;
    end
    
else
    time = time - (dist(trajectory(end),trajectory(1,1))/vel) ;
    trajectory = [trajectory trajectory(1,1)];  % marking the end of journey..
    mdata = 0;
    for s = 1:N
        if(cluster_set(trajectory(1,1),s) == 1)
            mdata = mdata + max(survival_time(1,i) , time)*dgr;
        end
    end
end

mobile_data = mobile_data + mdata;  % collecting data from location...
%display("Mobile Data Collected : "+ mobile_data);
%display("Time utilised : "+ (T-time));
%display("Data generated : "+ Total_data);
ratio = mobile_data / Total_data;
display("Network Throughput : "+ ratio);

clear collection_time;
clear sojourn_time;
clear stoppage_time;


fid = fopen('C:\Users\lenovo\Desktop\MyOutput\Improved_Max_noOrigin_checkToWait_n=600_t=6400.txt','a+');
fprintf(fid,'%d', ratio);
fprintf(fid,'\r\n');
fclose(fid);

disp(w);
end