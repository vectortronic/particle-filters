function f = compute_likelihood(particle, N, blockSize, dt)

lambda = particle.beta(1,:) + particle.gamma(1,:).*cos(2*(particle.s(1,1) - particle.theta_p(1,:)));
%neuronal_likelihoods = ((lambda*dt).^N).*exp(-lambda*dt*blockSize);

neuronal_likelihoods = (factorial(blockSize)./(factorial(N).*factorial(blockSize-N))).*((lambda*dt).^N).*exp(-lambda*dt*blockSize);

f = prod(neuronal_likelihoods);
%disp(f);
