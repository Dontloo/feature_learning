% x is [rows*rows*chnls*pts]
% full/valid
function [cae] = cae_train(cae, x, opts)
    
    [x,para] = cae_check(cae,x,opts);
    
    for i=1:opts.numepochs
        disp(['epoch ' num2str(i) '/' num2str(opts.numepochs)]);
        tic;
        rdm_idx = randperm(para.pnum);
        for j = 1 : para.bnum
            batch_x = x(:,:,:,rdm_idx((j-1)*para.bsze+1:j*para.bsze));
            x_noise = batch_x;
            cae = cae_up(cae, x_noise, para); % h_k
            cae.h_pool = cae.h;
%             cae = cae_pool(cae, para); % h_k'
            cae = cae_down(cae, para); % y
            cae = cae_grad(cae, batch_x, para); 
%             [numdw,numdb,numdc] = cae_check_grad(cae, batch_x, para); % correct for multi channel input data
            cae = cae_update(cae, opts); % w w_tilde            
            disp(cae.loss);
        end
        toc;
    end
end

function [x,para] = cae_check(cae, x, opts)
    if numel(size(x))<4
        x = reshape(x,[size(x,1) size(x,2) 1 size(x,3)]);
    end
    para.m = size(x,1);
    para.pnum = size(x,4); % number of data points
    para.pgrds = (para.m-cae.ks+1)/cae.ps; % pool grids
    para.bsze = opts.batchsize; % batch size
    para.bnum = para.pnum/para.bsze; % number of batches
    
    if size(x,3)~=cae.ic
        error('number of input chanels doesn''t match');
    end
    
    if cae.ks>para.m
        error('too large kernel');
    end
    
    if floor(para.pgrds)~=para.pgrds
        error('sides of hidden representations should be divisible by pool size')
    end
    
    if floor(para.bnum)~=para.bnum
        error('number of data points should be divisible by batch size.');
    end
end

function [cae] = cae_up(cae, x, para)
    % ks: kernel size, oc: output channels
    cae.h = zeros(para.m-cae.ks+1,para.m-cae.ks+1,cae.oc,para.bsze);
    for pt = 1:para.bsze
        for oc = 1:cae.oc
            for ic = 1:cae.ic
                cae.h(:,:,oc,pt) = cae.h(:,:,oc,pt) + convn(x(:,:,ic,pt),cae.w(:,:,ic,oc),'valid');
            end
            cae.h(:,:,oc,pt) = sigm(cae.h(:,:,oc,pt)+cae.b(oc));
        end        
    end
end

function cae = cae_pool(cae, para)
    % ps: pool size
    cae.h_pool = zeros(size(cae.h));
    for i = 1:para.pgrds
        for j = 1:para.pgrds
            cae.h_pool((i-1)*cae.ps+1:i*cae.ps,(j-1)*cae.ps+1:j*cae.ps,:,:) = repmat(max(max(cae.h((i-1)*cae.ps+1:i*cae.ps,(j-1)*cae.ps+1:j*cae.ps,:,:))),cae.ps,cae.ps);
        end
    end        
end

function [cae] = cae_down(cae, para)
    % ks: kernel size, oc: output channels
    cae.o = zeros(para.m,para.m,cae.ic,para.bsze);
    for pt = 1:para.bsze
        for ic = 1:cae.ic
            for oc = 1:cae.oc
                cae.o(:,:,ic,pt) = cae.o(:,:,ic,pt) + convn(cae.h_pool(:,:,oc,pt),cae.w_tilde(:,:,ic,oc),'full');
            end
            cae.o(:,:,ic,pt) = sigm(cae.o(:,:,ic,pt)+cae.c(ic));
        end        
    end
end

function [cae] = cae_grad(cae, x, para)
    % todo: derivatives of max pooling
    cae.err = cae.o-x;
    cae.loss = 1/2 * sum(cae.err(:) .^2 )/para.bsze;
    % dy' = (y-x)(y(1-y))
    cae.dy = cae.err.*(cae.o.*(1-cae.o));
    cae.dh = zeros(size(cae.h));
    cae.dc = zeros([size(cae.c) para.bsze]);
    cae.db = zeros([size(cae.b) para.bsze]);
    cae.dw = zeros([size(cae.w) para.bsze]);
        
    cae.dc = reshape(sum(sum(cae.dy)),size(cae.dc));
    for pt = 1:para.bsze
        for oc = 1:cae.oc
            for ic = 1:cae.ic
                cae.dh(:,:,oc,pt) = cae.dh(:,:,oc,pt)+convn(cae.dy(:,:,ic,pt),cae.w(:,:,ic,oc),'valid');
            end   
            % todo: d(h_pool)\d(h)
            cae.dh(:,:,oc,pt) = cae.dh(:,:,oc,pt).*(cae.h(:,:,oc,pt).*(1-cae.h(:,:,oc,pt)));            
        end        
    end    
    
    cae.db = reshape(sum(sum(cae.dh)),size(cae.db));
%     cae.h_tilde = flip(flip(cae.h,1),2);
    cae.dy_tilde = flip(flip(cae.dy,1),2);
    x_tilde = flip(flip(x,1),2);
    for pt = 1:para.bsze
        for oc = 1:cae.oc
            for ic = 1:cae.ic                
%                 cae.dw(:,:,ic,oc,pt) = convn(x_tilde(:,:,ic,pt),cae.dh(:,:,oc,pt),'valid')+flip(flip(convn(cae.dy(:,:,ic,pt),cae.h_tilde(:,:,oc,pt),'valid'),1),2);
                % x~ * dh + dy~ * h, perfect                
                cae.dw(:,:,ic,oc,pt) = convn(x_tilde(:,:,ic,pt),cae.dh(:,:,oc,pt),'valid')+convn(cae.dy_tilde(:,:,ic,pt),cae.h(:,:,oc,pt),'valid');
            end
        end        
    end    
    cae.dc = sum(cae.dc,numel(size(cae.dc)))/para.bsze;
    cae.db = sum(cae.db,numel(size(cae.db)))/para.bsze;
    cae.dw = sum(cae.dw,numel(size(cae.dw)))/para.bsze;    
end

function [cae] = cae_update(cae, opts)
    cae.b = cae.b - opts.alpha*cae.db;
    cae.c = cae.c - opts.alpha*cae.dc;
    cae.w = cae.w - opts.alpha*cae.dw;
    cae.w_tilde = flip(flip(cae.w,1),2);
end

function [numdw,numdb,numdc] = cae_check_grad(cae, x, para)
    epsilon = 1e-5;
    
    numdw = zeros(size(cae.dw));
    numdc = zeros(size(cae.dc));
    numdb = zeros(size(cae.db));
    
    % dc
    for ic = 1:cae.ic
        cae_h = cae;                    
        cae_h.c(ic) = cae_h.c(ic)+epsilon;
        x_noise = x;
        cae_h = cae_up(cae_h, x_noise, para); % h_k
        cae_h.h_pool = cae_h.h;
        cae_h = cae_down(cae_h, para); % y
        cae_h = cae_grad(cae_h, x, para);

        cae_l = cae;
        cae_l.c(ic) = cae_l.c(ic)-epsilon;
        x_noise = x;
        cae_l = cae_up(cae_l, x_noise, para); % h_k
        cae_l.h_pool = cae_l.h;
        cae_l = cae_down(cae_l, para); % y
        cae_l = cae_grad(cae_l, x, para); 
        
        numdc(ic) = (cae_h.loss - cae_l.loss) / (2 * epsilon);
    end
    % db
    for oc = 1:cae.oc
        cae_h = cae;                    
        cae_h.b(oc) = cae_h.b(oc)+epsilon;
        x_noise = x;
        cae_h = cae_up(cae_h, x_noise, para); % h_k
        cae_h.h_pool = cae_h.h;
        cae_h = cae_down(cae_h, para); % y
        cae_h = cae_grad(cae_h, x, para);

        cae_l = cae;
        cae_l.b(oc) = cae_l.b(oc)-epsilon;
        x_noise = x;
        cae_l = cae_up(cae_l, x_noise, para); % h_k
        cae_l.h_pool = cae_l.h;
        cae_l = cae_down(cae_l, para); % y
        cae_l = cae_grad(cae_l, x, para); 
        
        numdb(oc) = (cae_h.loss - cae_l.loss) / (2 * epsilon);
    end
    % dw
    for ic = 1:cae.ic
        for oc = 1:cae.oc
            for m = 1:cae.ks
                for n = 1:cae.ks
                    cae_h = cae;                            
                    cae_h.w(m,n,ic,oc) = cae_h.w(m,n,ic,oc)+epsilon; % identical as convn(x_tilde(:,:,ic,pt),cae.dh(:,:,oc,pt),'valid');
                    cae_h.w_tilde(cae.ks+1-m,cae.ks+1-n,ic,oc) = cae_h.w_tilde(cae.ks+1-m,cae.ks+1-n,ic,oc)+epsilon;                                                     
                    x_noise = x;
                    cae_h = cae_up(cae_h, x_noise, para); % h_k
                    cae_h.h_pool = cae_h.h;
                    cae_h = cae_down(cae_h, para); % y
                    cae_h = cae_grad(cae_h, x, para);
                    
                    cae_l = cae;
                    cae_l.w(m,n,ic,oc) = cae_l.w(m,n,ic,oc)-epsilon;
                    cae_l.w_tilde(cae.ks+1-m,cae.ks+1-n,ic,oc) = cae_l.w_tilde(cae.ks+1-m,cae.ks+1-n,ic,oc)-epsilon;    
                    x_noise = x;
                    cae_l = cae_up(cae_l, x_noise, para); % h_k
                    cae_l.h_pool = cae_l.h;
                    cae_l = cae_down(cae_l, para); % y
                    cae_l = cae_grad(cae_l, x, para); 
                    
                    numdw(m,n,ic,oc) = (cae_h.loss - cae_l.loss) / (2 * epsilon);
                end
            end           
        end
    end
end