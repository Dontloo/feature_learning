function [x] = align_data(x)
    if numel(size(x))<4
        x = reshape(x,[size(x,1) size(x,2) 1 size(x,3)]);
    end
end