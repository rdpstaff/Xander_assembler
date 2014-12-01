def estimate_optimal_with_N_and_M(N,M):
	Z = math.log(2)*(M/float(N))
	intZ = int(Z)
	if intZ == 0:
		intZ = 1
	H = int(M/intZ)
	M = H*intZ
	f1 = (0.5) ** intZ # inaccurate
	f2 = (1-math.exp(-N/float(H)))**intZ
	return intZ,H,M,f2
