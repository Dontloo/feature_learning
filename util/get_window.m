function [res] = get_window(im,m_idx,n_idx,m_ofst,n_ofst)
    res = im(m_idx-m_ofst+1:m_idx+m_ofst,n_idx-n_ofst+1:n_idx+n_ofst,:);
end

