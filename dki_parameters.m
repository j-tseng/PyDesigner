
function [fa, md, rd, ad, fe, mk, rk, ak, kfa, mkt] = dki_parameters(dt, mask, violMask, medianfilter)
% diffusion and kurtosis tensor parameter calculation
%
% -----------------------------------------------------------------------------------
% please cite: Veraart et al.
%              More Accurate Estimation of Diffusion Tensor Parameters Using Diffusion Kurtosis Imaging,
%              MRM 65 (2011): 138-145.
%------------------------------------------------------------------------------------
%
% Usage:
% ------
% [fa, md, ad, rd, fe, mk, ak, rk] = dki_parameters(dt [, mask [, branch]], medianfiltering)
%
% Required input:
% ---------------
%     1. dt: diffusion kurtosis tensor (cf. order of tensor elements cf. dki_fit.m)
%           [x, y, z, 21]
%
%     2. medianilter, 0 or 1
%              0: no median filtering
%              1: apply median filtering
%
% Optional input:
% ---------------
%    3. mask (boolean; [x, y, x]), providing a mask limits the
%       calculation to a user-defined region-of-interest.
%       default: mask = full FOV
%
%    4. branch selection, 1 or 2 (default: 1)
%              1. De_parallel > Da_parallel
%              2. Da_parallel > De_parallel
%
% Output:
% -------
%  1. fa:                fractional anisitropy
%  2. md:                mean diffusivity
%  3. rd:                radial diffusivity
%  4. ad:                axial diffusivity
%  5. fe:                principal direction of diffusivity
%  6. mk:                mean kurtosis
%  7. rk:                radial kurtosis
%  8. ak:                axial kurtosis
%  9. kfa:               kurtosis fractional anisotropy
%  10. mkt:              mean kurtosis tensor
%
% Important: The presence of outliers "black voxels" in the kurtosis maps
%            are we well-known, but inherent problem to DKI. Smoothing the
%            data in addition to the typical data preprocessing steps
%            might minimize the impact of those voxels on the visual
%            and statistical interpretation. However, smoothing comes
%            with the cost of partial voluming.
%
% Copyright (c) 2017 New York University and University of Antwerp
%
% This Source Code Form is subject to the terms of the Mozilla Public
% License, v. 2.0. If a copy of the MPL was not distributed with this file,
% You can obtain one at http://mozilla.org/MPL/2.0/
%
% This code is distributed  WITHOUT ANY WARRANTY; without even the
% implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
%
% For more details, contact: Jelle.Veraart@nyumc.org


n = size(dt, 4);
if ndims(dt)~=4
    error('size of dt needs to be [x, y, z, 21]')
end
if n~=21
    error('dt needs to contain 21')
end
if ~exist('mask','var') || isempty(mask)
    mask = ~isnan(dt(:,:,:,1));
end

dt = vectorize(dt, mask);
nvoxels = size(dt, 2);


%% DTI parameters
for i = 1:nvoxels
    DT = dt([1:3 2 4 5 3 5 6], i);
    DT = reshape(DT, [3 3]);
    try
        [eigvec, eigval] = eigs(DT);
        eigval = diag(eigval);
    catch
        eigvec = NaN(3, 3);
        eigval = NaN(3, 1);
    end
    [eigval, idx] = sort(eigval, 'descend');
    eigvec = eigvec(:, idx);
    l1(i) = eigval(1,:);
    l2(i) = eigval(2,:);
    l3(i) = eigval(3,:);
    
    e1(:, i) = eigvec(:, 1);
end
md = (l1+l2+l3)/3;

rd = (l2+l3)/2;
ad = l1;
fa = sqrt(1/2).*sqrt((l1-l2).^2+(l2-l3).^2+(l3-l1).^2)./sqrt(l1.^2+l2.^2+l3.^2);

%% DKI parameters
dirs = get256dirs();
akc = AKC(dt, dirs);

mk = mean(akc);
ak = zeros([1, size(e1,2)]);
rk = zeros([1, size(e1,2)]);

parfor i = 1:nvoxels
    dirs = [e1(:,i), -e1(:,i)]';
    akc = AKC(dt(:,i), dirs);
    ak(i) = mean(akc);
    dirs = radialsampling(e1(:,i), 256)';
    akc = AKC(dt(:,i), dirs);
    rk(i) = mean(akc);
    [kfa(i),mkt(i)] = ComputeKFA(dt(:,i),3,0)   % [0 3] define the range of
    %   kurtosis to use in the calculation of KFA
end

%% return maps
fa  = vectorize(fa, mask);
md  = vectorize(md, mask);
ad  = vectorize(ad, mask);
rd  = vectorize(rd, mask);
mk  = vectorize(mk, mask);
ak  = vectorize(ak, mask);
rk  = vectorize(rk, mask);
fe  = vectorize(e1, mask);
kfa = vectorize(kfa, mask);
mkt = vectorize(mkt, mask);

%% Median filter maps
% First create median filtering object based on MK
if medianfilter
    % Specify threshold at 10% to filter voxels with more than 10%
    % violations
    persistent medianFilter;
    medianFilter = createFiltObj(mk, violMask, 0.1, 3);
    
    % Then apply filter to all maps
    if medianFilter.FilterStatus == 1
        fa = applyMedFilt(fa, medianFilter);
        md = applyMedFilt(md, medianFilter);
        ad = applyMedFilt(ad, medianFilter);
        rd = applyMedFilt(rd, medianFilter);
        mk = applyMedFilt(mk, medianFilter);
        ak = applyMedFilt(ak, medianFilter);
        rk = applyMedFilt(rk, medianFilter);
        kfa = applyMedFilt(kfa, medianFilter);
        mkt = applyMedFilt(mkt, medianFilter);
    else
        disp('...no median filtering specified');
    end
end
end

function dirs = get256dirs()
dirs =  [0         0    1.0000;
    0.5924         0    0.8056;
    -0.7191   -0.1575   -0.6768;
    -0.9151   -0.3479    0.2040;
    0.5535    0.2437    0.7964;
    -0.0844    0.9609   -0.2636;
    0.9512   -0.3015    0.0651;
    -0.4225    0.8984    0.1202;
    0.5916   -0.6396    0.4909;
    0.3172    0.8818   -0.3489;
    -0.1988   -0.6687    0.7164;
    -0.2735    0.3047   -0.9123;
    0.9714   -0.1171    0.2066;
    -0.5215   -0.4013    0.7530;
    -0.3978   -0.9131   -0.0897;
    0.2680    0.8196    0.5063;
    -0.6824   -0.6532   -0.3281;
    0.4748   -0.7261   -0.4973;
    0.4504   -0.4036    0.7964;
    -0.5551   -0.8034   -0.2153;
    0.0455   -0.2169    0.9751;
    0.0483    0.5845    0.8099;
    -0.1909   -0.1544   -0.9694;
    0.8383    0.5084    0.1969;
    -0.2464    0.1148    0.9623;
    -0.7458    0.6318    0.2114;
    -0.0080   -0.9831   -0.1828;
    -0.2630    0.5386   -0.8005;
    -0.0507    0.6425   -0.7646;
    0.4476   -0.8877    0.1081;
    -0.5627    0.7710    0.2982;
    -0.3790    0.7774   -0.5020;
    -0.6217    0.4586   -0.6350;
    -0.1506    0.8688   -0.4718;
    -0.4579    0.2131    0.8631;
    -0.8349   -0.2124    0.5077;
    0.7682   -0.1732   -0.6163;
    0.0997   -0.7168   -0.6901;
    0.0386   -0.2146   -0.9759;
    0.9312    0.1655   -0.3249;
    0.9151    0.3053    0.2634;
    0.8081    0.5289   -0.2593;
    -0.3632   -0.9225    0.1305;
    0.2709   -0.3327   -0.9033;
    -0.1942   -0.9790   -0.0623;
    0.6302   -0.7641    0.1377;
    -0.6948   -0.3137    0.6471;
    -0.6596   -0.6452    0.3854;
    -0.9454    0.2713    0.1805;
    -0.2586   -0.7957    0.5477;
    -0.3576    0.6511    0.6695;
    -0.8490   -0.5275    0.0328;
    0.3830    0.2499   -0.8893;
    0.8804   -0.2392   -0.4095;
    0.4321   -0.4475   -0.7829;
    -0.5821   -0.1656    0.7961;
    0.3963    0.6637    0.6344;
    -0.7222   -0.6855   -0.0929;
    0.2130   -0.9650   -0.1527;
    0.4737    0.7367   -0.4825;
    -0.9956    0.0891    0.0278;
    -0.5178    0.7899   -0.3287;
    -0.8906    0.1431   -0.4317;
    0.2431   -0.9670    0.0764;
    -0.6812   -0.3807   -0.6254;
    -0.1091   -0.5141    0.8507;
    -0.2206    0.7274   -0.6498;
    0.8359    0.2674    0.4794;
    0.9873    0.1103    0.1147;
    0.7471    0.0659   -0.6615;
    0.6119   -0.2508    0.7502;
    -0.6191    0.0776    0.7815;
    0.7663   -0.4739    0.4339;
    -0.5699    0.5369    0.6220;
    0.0232   -0.9989    0.0401;
    0.0671   -0.4207   -0.9047;
    -0.2145    0.5538    0.8045;
    0.8554   -0.4894    0.1698;
    -0.7912   -0.4194    0.4450;
    -0.2341    0.0754   -0.9693;
    -0.7725    0.6346   -0.0216;
    0.0228    0.7946   -0.6067;
    0.7461   -0.3966   -0.5348;
    -0.4045   -0.0837   -0.9107;
    -0.4364    0.6084   -0.6629;
    0.6177   -0.3175   -0.7195;
    -0.4301   -0.0198    0.9026;
    -0.1489   -0.9706    0.1892;
    0.0879    0.9070   -0.4117;
    -0.7764   -0.4707   -0.4190;
    0.9850    0.1352   -0.1073;
    -0.1581   -0.3154    0.9357;
    0.8938   -0.3246    0.3096;
    0.8358   -0.4464   -0.3197;
    0.4943    0.4679    0.7327;
    -0.3095    0.9015   -0.3024;
    -0.3363   -0.8942   -0.2956;
    -0.1271   -0.9274   -0.3519;
    0.3523   -0.8717   -0.3407;
    0.7188   -0.6321    0.2895;
    -0.7447    0.0924   -0.6610;
    0.1622    0.7186    0.6762;
    -0.9406   -0.0829   -0.3293;
    -0.1229    0.9204    0.3712;
    -0.8802    0.4668    0.0856;
    -0.2062   -0.1035    0.9730;
    -0.4861   -0.7586   -0.4338;
    -0.6138    0.7851    0.0827;
    0.8476    0.0504    0.5282;
    0.3236    0.4698   -0.8213;
    -0.7053   -0.6935    0.1473;
    0.1511    0.3778    0.9135;
    0.6011    0.5847    0.5448;
    0.3610    0.3183    0.8766;
    0.9432    0.3304    0.0341;
    0.2423   -0.8079   -0.5372;
    0.4431   -0.1578    0.8825;
    0.6204    0.5320   -0.5763;
    -0.2806   -0.5376   -0.7952;
    -0.5279   -0.8071    0.2646;
    -0.4214   -0.6159    0.6656;
    0.6759   -0.5995   -0.4288;
    0.5670    0.8232   -0.0295;
    -0.0874    0.4284   -0.8994;
    0.8780   -0.0192   -0.4782;
    0.0166    0.8421    0.5391;
    -0.7741    0.2931   -0.5610;
    0.9636   -0.0579   -0.2611;
    0         0   -1.0000;
    -0.5924         0   -0.8056;
    0.7191    0.1575    0.6768;
    0.9151    0.3479   -0.2040;
    -0.5535   -0.2437   -0.7964;
    0.0844   -0.9609    0.2636;
    -0.9512    0.3015   -0.0651;
    0.4225   -0.8984   -0.1202;
    -0.5916    0.6396   -0.4909;
    -0.3172   -0.8818    0.3489;
    0.1988    0.6687   -0.7164;
    0.2735   -0.3047    0.9123;
    -0.9714    0.1171   -0.2066;
    0.5215    0.4013   -0.7530;
    0.3978    0.9131    0.0897;
    -0.2680   -0.8196   -0.5063;
    0.6824    0.6532    0.3281;
    -0.4748    0.7261    0.4973;
    -0.4504    0.4036   -0.7964;
    0.5551    0.8034    0.2153;
    -0.0455    0.2169   -0.9751;
    -0.0483   -0.5845   -0.8099;
    0.1909    0.1544    0.9694;
    -0.8383   -0.5084   -0.1969;
    0.2464   -0.1148   -0.9623;
    0.7458   -0.6318   -0.2114;
    0.0080    0.9831    0.1828;
    0.2630   -0.5386    0.8005;
    0.0507   -0.6425    0.7646;
    -0.4476    0.8877   -0.1081;
    0.5627   -0.7710   -0.2982;
    0.3790   -0.7774    0.5020;
    0.6217   -0.4586    0.6350;
    0.1506   -0.8688    0.4718;
    0.4579   -0.2131   -0.8631;
    0.8349    0.2124   -0.5077;
    -0.7682    0.1732    0.6163;
    -0.0997    0.7168    0.6901;
    -0.0386    0.2146    0.9759;
    -0.9312   -0.1655    0.3249;
    -0.9151   -0.3053   -0.2634;
    -0.8081   -0.5289    0.2593;
    0.3632    0.9225   -0.1305;
    -0.2709    0.3327    0.9033;
    0.1942    0.9790    0.0623;
    -0.6302    0.7641   -0.1377;
    0.6948    0.3137   -0.6471;
    0.6596    0.6452   -0.3854;
    0.9454   -0.2713   -0.1805;
    0.2586    0.7957   -0.5477;
    0.3576   -0.6511   -0.6695;
    0.8490    0.5275   -0.0328;
    -0.3830   -0.2499    0.8893;
    -0.8804    0.2392    0.4095;
    -0.4321    0.4475    0.7829;
    0.5821    0.1656   -0.7961;
    -0.3963   -0.6637   -0.6344;
    0.7222    0.6855    0.0929;
    -0.2130    0.9650    0.1527;
    -0.4737   -0.7367    0.4825;
    0.9956   -0.0891   -0.0278;
    0.5178   -0.7899    0.3287;
    0.8906   -0.1431    0.4317;
    -0.2431    0.9670   -0.0764;
    0.6812    0.3807    0.6254;
    0.1091    0.5141   -0.8507;
    0.2206   -0.7274    0.6498;
    -0.8359   -0.2674   -0.4794;
    -0.9873   -0.1103   -0.1147;
    -0.7471   -0.0659    0.6615;
    -0.6119    0.2508   -0.7502;
    0.6191   -0.0776   -0.7815;
    -0.7663    0.4739   -0.4339;
    0.5699   -0.5369   -0.6220;
    -0.0232    0.9989   -0.0401;
    -0.0671    0.4207    0.9047;
    0.2145   -0.5538   -0.8045;
    -0.8554    0.4894   -0.1698;
    0.7912    0.4194   -0.4450;
    0.2341   -0.0754    0.9693;
    0.7725   -0.6346    0.0216;
    -0.0228   -0.7946    0.6067;
    -0.7461    0.3966    0.5348;
    0.4045    0.0837    0.9107;
    0.4364   -0.6084    0.6629;
    -0.6177    0.3175    0.7195;
    0.4301    0.0198   -0.9026;
    0.1489    0.9706   -0.1892;
    -0.0879   -0.9070    0.4117;
    0.7764    0.4707    0.4190;
    -0.9850   -0.1352    0.1073;
    0.1581    0.3154   -0.9357;
    -0.8938    0.3246   -0.3096;
    -0.8358    0.4464    0.3197;
    -0.4943   -0.4679   -0.7327;
    0.3095   -0.9015    0.3024;
    0.3363    0.8942    0.2956;
    0.1271    0.9274    0.3519;
    -0.3523    0.8717    0.3407;
    -0.7188    0.6321   -0.2895;
    0.7447   -0.0924    0.6610;
    -0.1622   -0.7186   -0.6762;
    0.9406    0.0829    0.3293;
    0.1229   -0.9204   -0.3712;
    0.8802   -0.4668   -0.0856;
    0.2062    0.1035   -0.9730;
    0.4861    0.7586    0.4338;
    0.6138   -0.7851   -0.0827;
    -0.8476   -0.0504   -0.5282;
    -0.3236   -0.4698    0.8213;
    0.7053    0.6935   -0.1473;
    -0.1511   -0.3778   -0.9135;
    -0.6011   -0.5847   -0.5448;
    -0.3610   -0.3183   -0.8766;
    -0.9432   -0.3304   -0.0341;
    -0.2423    0.8079    0.5372;
    -0.4431    0.1578   -0.8825;
    -0.6204   -0.5320    0.5763;
    0.2806    0.5376    0.7952;
    0.5279    0.8071   -0.2646;
    0.4214    0.6159   -0.6656;
    -0.6759    0.5995    0.4288;
    -0.5670   -0.8232    0.0295;
    0.0874   -0.4284    0.8994;
    -0.8780    0.0192    0.4782;
    -0.0166   -0.8421   -0.5391;
    0.7741   -0.2931    0.5610;
    -0.9636    0.0579    0.2611];
end

function [akc, adc] = AKC(dt, dir)

[W_ind, W_cnt] = createTensorOrder(4);

adc = ADC(dt(1:6, :), dir);
md = sum(dt([1 4 6],:),1)/3;

ndir  = size(dir, 1);
T =  W_cnt(ones(ndir, 1), :).*dir(:,W_ind(:, 1)).*dir(:,W_ind(:, 2)).*dir(:,W_ind(:, 3)).*dir(:,W_ind(:, 4));

akc =  T*dt(7:21, :);
akc = (akc .* repmat(md.^2, [size(adc, 1), 1]))./(adc.^2);
end

function [adc] = ADC(dt, dir)
[D_ind, D_cnt] = createTensorOrder(2);
ndir  = size(dir, 1);
T =  D_cnt(ones(ndir, 1), :).*dir(:,D_ind(:, 1)).*dir(:,D_ind(:, 2));
adc = T * dt;
end

function [X, cnt] = createTensorOrder(order)

%     X = nchoosek(kron([1, 2, 3], ones(1, order)), order);
%     X = unique(X, 'rows');
%     for i = 1:size(X, 1)
%         cnt(i) = factorial(order) / factorial(nnz(X(i, :) ==1))/ factorial(nnz(X(i, :) ==2))/ factorial(nnz(X(i, :) ==3));
%     end

if order == 2
    X = [1 1; ...
        1 2; ...
        1 3; ...
        2 2; ...
        2 3; ...
        3 3];
    cnt = [1 2 2 1 2 1];
end

if order == 4
    X = [1 1 1 1; ...
        1 1 1 2; ...
        1 1 1 3; ...
        1 1 2 2; ...
        1 1 2 3; ...
        1 1 3 3; ...
        1 2 2 2; ...
        1 2 2 3; ...
        1 2 3 3; ...
        1 3 3 3; ...
        2 2 2 2; ...
        2 2 2 3; ...
        2 2 3 3; ...
        2 3 3 3; ...
        3 3 3 3];
    cnt = [1 4 4 6 12 6 4 12 12 4 1 4 6 4 1];
end

end

function dirs = radialsampling(dir, n)

% compute Equator Points

dt = 2*pi/n;
theta = 0:dt:(2*pi-dt);

dirs = [cos(theta)', sin(theta)', 0*theta']';

v = [-dir(2), dir(1), 0];
s = sqrt(sum(v.^2));
c = dir(3);
V = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
R = eye(3) + V + V*V * (1-c)/s^2;

dirs = R*dirs;

end

function [s, mask] = vectorize(S, mask)
if nargin == 1
    mask = ~isnan(S(:,:,:,1));
end
if ismatrix(S)
    n = size(S, 1);
    [x, y, z] = size(mask);
    s = NaN([x, y, z, n], 'like', S);
    for i = 1:n
        tmp = NaN(x, y, z, 'like', S);
        tmp(mask(:)) = S(i, :);
        s(:,:,:,i) = tmp;
    end
else
    for i = 1:size(S, 4)
        Si = S(:,:,:,i);
        s(i, :) = Si(mask(:));
    end
end
end

function [kfa,mkt] = ComputeKFA(dt,Kmax_final,Kmin_final)
%
% computes the kfa given a 15-vector of kurtosis tensor values
%
% Author: Mark Van Horn, Emilie McKinnon, and Siddhartha Dhiman
% Last modified: 01/03/19

offset = 6; %   Number of DT elements prior to KT elements in dt

W1111 = dt(1+offset);
W1112 = dt(2+offset);
W1113 = dt(3+offset);
W1122 = dt(4+offset);
W1123 = dt(5+offset);
W1133 = dt(6+offset);
W1222 = dt(7+offset);
W1223 = dt(8+offset);
W1233 = dt(9+offset);
W1333 = dt(10+offset);
W2222 = dt(11+offset);
W2223 = dt(12+offset);
W2233 = dt(13+offset);
W2333 = dt(14+offset);
W3333 = dt(15+offset);

W_F = sqrt(W1111^2 + W2222^2 + W3333^2 + 6 * W1122^2 + 6 * W1133^2 +...
    6 * W2233^2 + 4 * W1112^2 + 4 * W1113^2 + 4 * W1222^2 + 4 *...
    W2223^2 + 4 * W1333^2 + 4 * W2333^2 + 12 * W1123^2 + 12 * W1223^2 +...
    12 * W1233^2);

Wbar = 1/5*(W1111 + W2222+ W3333 + 2*(W1122 + W1133 + W2233));

if W_F < 1e-3,
    kfa = 0;
else
    W_diff_F = sqrt((W1111 - Wbar)^2 + (W2222 - Wbar)^2 +...
        (W3333 - Wbar)^2 + 6 * (W1122 - Wbar / 3)^2 +...
        6*(W1133 - Wbar/3)^2 + 6*(W2233 - Wbar/3)^2 + 4*W1112^2 +...
        4*W1113^2 + 4*W1222^2 + 4*W2223^2 + 4*W1333^2 + 4*W2333^2 + ...
        12*W1123^2 + 12*W1223^2 + 12*W1233^2);
    
    kfa = W_diff_F / W_F;
end

mkt=Wbar;
mkt(mkt > Kmax_final) = Kmax_final;
mkt(mkt < Kmin_final) = Kmin_final;
end