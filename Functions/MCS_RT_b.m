function model_ranking_2 = MCS_RT_b(eps_temp_RT)

B = 10000;
l = 6;

loss_data = eps_temp_RT';

[model_ranking_2]=mcs_CB_RT_2(loss_data,0.25,B,l,'BLOCK');

end