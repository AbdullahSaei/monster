per = 40;

tSM = [0.071 1 10 1000];
SM = [1 2 3 4];

maxSleep = max(SM(cumsum(2*tSM)<per))
