clc
clear all
close all
load kinematics
tmax = 120;
tTrain = 120;
t = (0:dt:tmax-dt)';
s = kinematics(2, 1:tmax*(1/dt))';
clear kinematics

nParticles = 100;
blockSize  = 50;
sd.s1 = 0.01;
sd.s2 = 0.01;
sd.theta_p1 = 0.008;
sd.theta_p2 = 0.001;
gamma_const = 15;
beta_const = gamma_const;
theta_p_init = 2;

neuron_list = 1:158;

nIterations_training = floor((tTrain/dt)/blockSize);
nIterations= floor(length(t)/blockSize);
nNeurons = length(neuron_list);

P_new(1:nParticles) = struct('s',0,...
    'gamma', gamma_const*ones(1, 1),...
    'theta_p',zeros(1, 1),...
    'beta', beta_const*ones(1, 1),...
    'g',zeros(1,1),...
    'likelihood',zeros(1,1),...
    'resampled_likelihood',zeros(1,1),...
    'w',ones(1,1));
P_old = P_new;


% initialize first iteration
for p =1:nParticles
    P_old(p).theta_p(1,1) = theta_p_init;
end
x_estimate.theta_p= zeros(nIterations, nNeurons);
x_estimate.s = zeros(nIterations, 1);
x_estimate.theta_p(1, :) = theta_p_init;
x_estimate.s(1,1) = s(1,1);
s_ds = downsample(s, blockSize);

for n = 1:nNeurons
    
    for p =1:nParticles
        P_old(p).theta_p(1,1) = theta_p_init;
    end
    
    neuron_number = neuron_list(n);
    disp(['training neuron ', num2str(n), ' of ', num2str(nNeurons)]);
    
    eval(['load neuron', num2str(neuron_number)]);
    eval(['N(:,1) = N', num2str(neuron_number), '(1:length(s));']);
    eval(['clear N', num2str(neuron_number), ' N', num2str(neuron_number)]);
    
    for k = 2:nIterations_training
        % disp(['block number ', num2str(k), ' of ', num2str(nIterations)]);
        % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
        % % % % % % % % Step1: draw random samples  % % % % % % %
        for p = 1:nParticles
            P_new(p).s(1,1) = s_ds(k);
            flag = true;
            while flag
                v = P_old(p).theta_p(1,1)+ sd.theta_p1*randn;
                if v > 0 && v < pi
                    P_new(p).theta_p(1,1) = v;
                    flag = false;
                end
            end
            temp.theta_p(p,1) = P_new(p).theta_p(1,1);
        end
        
        % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
        % % % % % % % % Step2: compute likelihoods % % % % % % % %
        norm_sum = 0;
        for p = 1:nParticles
            particle = P_new(p);
            blockStart = (k-1)*blockSize + 1;
            blockEnd   = blockStart + blockSize - 1;
            nFirings = sum(N(blockStart:blockEnd,:),1);
            P_new(p).likelihood(1,1)=compute_likelihood(particle, nFirings, blockSize, dt);
            P_new(p).g(1,1) = P_old(p).w((1),1)*P_new(p).likelihood(1,1);
            norm_sum = norm_sum + P_new(p).g(1,1);
        end
        % normalize
        prob_vector = zeros(1, nParticles);
        for p = 1:nParticles
            P_new(p).g(1,1) = P_new(p).g(1,1)/norm_sum;
            prob_vector(1,p) = P_new(p).g(1,1);
        end
        
        % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
        % % % % % % % % Step 3: resample % % % % % % % % % % % % %
        resampleIndicies = randsample((1:nParticles), nParticles, 'true', prob_vector);
        for p = 1:nParticles
            P_new(p).theta_p(1,1)=temp.theta_p(resampleIndicies(p),1);
        end
        
        % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
        % % % % % % % % Ste 4: draw random samples  % % % % % % %
        for p = 1:nParticles
            P_new(p).s(1,1) = s_ds(k);
            flag = true;
            while flag
                v = P_new(p).theta_p(1,1)+ sd.theta_p2*randn;
                if v > 0 && v < pi
                    P_new(p).theta_p(1,1) = v;
                    flag = false;
                end
            end
        end
        % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
        % % % % % % % % Step 5: Compute resampled likelihoods % %
        norm_sum = 0;
        for p = 1:nParticles
            particle = P_new(p);
            P_new(p).resampled_likelihood(1,1) = compute_likelihood(particle, nFirings, blockSize, dt);
            P_new(p).w(1,1) = P_new(p).resampled_likelihood(1,1)/P_new(p).likelihood(1,1);
            norm_sum = norm_sum + P_new(p).w(1,1);
        end
        % normalize
        for p = 1:nParticles
            P_new(p).w(1,1) = P_new(p).w(1,1)/norm_sum;
        end
        % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
        % Step 6: Compute weighted estimate % % % % % % % % % % %
        for p = 1:nParticles
            x_estimate.theta_p(k,n) = P_new(p).theta_p(1,1)*P_new(p).w(1,1) + x_estimate.theta_p(k,n);
            x_estimate.s(k,1) = s_ds(k,1);
        end
        P_old = P_new;
    end
end

theta_p_init = x_estimate.theta_p(end, :);
s_init = x_estimate.s(end,1);

save training_data
save initial_conditions k gamma_const beta_const ...
    blockSize dt nNeurons neuron_list nIterations_training ...
    theta_p_init s_init

t2 = 0:dt*blockSize:tmax-dt;
for k = 1:nNeurons
    figure(neuron_list(k)),
    set(gcf,'WindowStyle','docked'),
    plot(t2, s_ds, 'LineWidth', 2), hold on,
    plot(t2, x_estimate.theta_p(:,k), 'r'), grid on, ...
        xlim([0 tmax]), ylim([0 pi]);
end


% figure, plot(t2, x_estimate.theta_p(:,2))
% figure, plot(t2, x_estimate.theta_p(:,3))