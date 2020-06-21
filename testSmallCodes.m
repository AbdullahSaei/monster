per = 10;
min = 2;

for count = 1:50
    if mod(count,per)-(per-min) >= 0 || mod(count,per) == 0
       fprintf('%d\n',count); 
    end
end