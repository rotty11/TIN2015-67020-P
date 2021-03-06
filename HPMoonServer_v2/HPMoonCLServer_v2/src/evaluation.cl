/**
 * @file evaluation.cl
 * @author Juan José Escobar Pérez
 * @date 12/07/2015
 * @brief File with the necessary implementation for the k-means algorithm in OpenCL
 *
 */

/********************************* Includes ********************************/

#include "individual.h" // Individual

/*********************************** Defines *********************************/

/**
 * @brief Max iterations for the convergence of centroids
 */
#define MAX_ITER_KMEANS 20

/********************************* Kernels ********************************/

/**
 * @brief Computes the k-means algorithm in a OpenCL CPU device
 * @param pop OpenCL object which contains the current population. The object is stored in global memory
 * @param selInstances OpenCL object which contains the instances choosen as initial centroids. The object is stored in constant memory
 * @param dataBase OpenCL object which contains the database. The object is stored in global memory
 * @param begin The first individual to evaluate
 * @param end The "end-1" position is the last individual to evaluate
 */
__kernel void kmeansCPU(__global struct individual *pop, __constant int *selInstances, __constant float *dataBase, const int begin, const int end) {

	uint groupId = get_group_id(0);
	uint numGroups = get_num_groups(0);

	const int totalCoord = KMEANS * N_FEATURES;

	uchar mapping[N_INSTANCES];
	float centroids[KMEANS * N_FEATURES];
	float distCentroids[N_INSTANCES];
	int samples_in_k[KMEANS];

	// Each work-item compute an individual (master-slave as a deck algorithm)
	for (int ind = begin + groupId; ind < end; ind += numGroups) {

		// The centroids will have the selected features of the individual
		for (int k = 0; k < KMEANS; ++k) {
			int posDataBase = selInstances[k] * N_FEATURES;
			int posCentr = k * N_FEATURES;

			for (int f = 0; f < N_FEATURES; ++f) {
				centroids[posCentr + f] = dataBase[posDataBase + f];
			}
		}

		// Initialize the mapping table
		for (int i = 0; i < N_INSTANCES; ++i) {
			mapping[i] = 0;
		}


		/******************** Convergence process *********************/

		// To avoid poor performance, at most "MAX_ITER_KMEANS" iterations are executed
		for (int maxIter = 0; maxIter < MAX_ITER_KMEANS; ++maxIter) {

			//printf("\nIter: %d\n", maxIter);
			for (int k = 0; k < KMEANS; ++k) {
				samples_in_k[k] = 0;
			}

			// Calculate all distances (Euclidean distance) between each instance and the centroids
			for (int i = 0; i < N_INSTANCES; ++i) {
				float minDist = INFINITY;
				int selectCentroid;
				int pos = N_FEATURES * i;
				for (int k = 0, posCentr = 0; k < KMEANS; ++k, posCentr += N_FEATURES) {
					float dist = 0.0f;
					for (int f = 0; f < N_FEATURES; ++f) {
						if (pop[ind].chromosome[f]) {
							float dif = dataBase[pos + f] - centroids[posCentr + f];
							dist += dif * dif;
						}
					}

					if (dist < minDist) {
						minDist = dist;
						selectCentroid = k;
					}
				}

				distCentroids[i] = minDist;
				samples_in_k[selectCentroid]++;

				if (mapping[i] != selectCentroid) {
					mapping[i] = selectCentroid;
				}
			}

			// Update the position of the centroids
			for (int k = 0; k < KMEANS; ++k) {
				int posCentr = k * N_FEATURES;
				for (int f = 0; f < N_FEATURES; ++f) {
					float sum = 0.0f;
					if (pop[ind].chromosome[f]) {
						for (int i = 0; i < N_INSTANCES; ++i) {
							if (mapping[i] == k) {
								sum += dataBase[(N_FEATURES * i) + f];
							}
						}
						centroids[posCentr + f] = sum / samples_in_k[k];
					}
				}
			}
		}


		/************ Minimize the within-cluster and maximize Inter-cluster sum of squares (WCSS and ICSS) *************/

		float sumWithin = 0.0f;
		float sumInter = 0.0f;

		// Within-cluster
		for (int i = 0; i < N_INSTANCES; ++i) {
			sumWithin += sqrt(distCentroids[i]);
		}

		// Inter-cluster
		for (int posCentr = 0; posCentr < totalCoord; posCentr += N_FEATURES) {
			for (int i = posCentr + N_FEATURES; i < totalCoord; i += N_FEATURES) {
				float sum = 0.0f;
				for (int f = 0; f < N_FEATURES; ++f) {
					if (pop[ind].chromosome[f]) {
						sum += (centroids[posCentr + f] - centroids[i + f]) * (centroids[posCentr + f] - centroids[i + f]);
					}
				}
				sumInter += sqrt(sum);
			}
		}

		// First objective function (Within-cluster sum of squares (WCSS))
		pop[ind].fitness[0] = sumWithin;

		// Second objective function (Inter-cluster sum of squares (ICSS))
		pop[ind].fitness[1] = sumInter;

		// Third objective function (Number of selected features)
		//pop[ind].fitness[2] = (float) nSelFeatures;
	}
}


/**
 * @brief Computes the k-means algorithm in a OpenCL GPU device
 * @param pop OpenCL object which contains the current population. The object is stored in global memory
 * @param selInstances OpenCL object which contains the instances choosen as initial centroids. The object is stored in constant memory
 * @param dataBase OpenCL object which contains the database. The object is stored in global memory
 * @param begin The first individual to evaluate
 * @param end The "end-1" position is the last individual to evaluate
 * @param dataBaseTransposed OpenCL object which contains the database transposed. The object is stored in global memory
 */
__kernel void kmeansGPU(__global struct individual *pop, __constant int *restrict selInstances, __global float *restrict dataBase, const int begin, const int end, __global float *restrict dataBaseTransposed) {

	uint localId = get_local_id(0);
	uint localSize = get_local_size(0);
	uint groupId = get_group_id(0);
	uint numGroups = get_num_groups(0);

	const int totalCoord = KMEANS * N_FEATURES;

	// The individual is cached into local memory to improve performance
	__local uchar chromosome[N_FEATURES];
	__local uchar mapping[N_INSTANCES];
	__local float centroids[KMEANS * N_FEATURES];
	__local float distCentroids[N_INSTANCES];
	__local int samples_in_k[KMEANS];

	event_t eventInd;
	event_t eventCentr;


	// Each work-group compute an individual (master-slave as a deck algorithm)
	for (int ind = begin + groupId; ind < end; ind += numGroups) {

		// The centroids will have the selected features of the individual
		for (int k = 0; k < KMEANS; ++k) {
			async_work_group_copy(centroids + (N_FEATURES * k), dataBase + (selInstances[k] * N_FEATURES), N_FEATURES, eventCentr); // Equal to the previous line
		}

		// The individual is cached to local memory for improve performance
		eventInd = async_work_group_copy(chromosome, pop[ind].chromosome, N_FEATURES, 0);

		// Initialize the mapping table
		for (int i = localId; i < N_INSTANCES; i += localSize) {
			mapping[i] = 0;
		}

		// Syncpoint
		wait_group_events(1, &eventInd);
		wait_group_events(1, &eventCentr);


		/******************** Convergence process *********************/

		// To avoid poor performance, at most "MAX_ITER_KMEANS" iterations are executed
		for (int maxIter = 0; maxIter < MAX_ITER_KMEANS; ++maxIter) {

			barrier(CLK_LOCAL_MEM_FENCE);
			for (int k = localId; k < KMEANS; k += localSize) {
				samples_in_k[k] = 0;
			}

			// Syncpoint
			barrier(CLK_LOCAL_MEM_FENCE);

			// Calculate all distances (Euclidean distance) between each instance and the centroids
			for (int i = localId; i < N_INSTANCES; i += localSize) {
				float minDist = INFINITY;
				int selectCentroid;
				for (int k = 0, posCentr = 0; k < KMEANS; ++k, posCentr += N_FEATURES) {
					float dist = 0.0f;
					for (int f = 0; f < N_FEATURES; ++f) {
						if (chromosome[f]) {
							float dif = dataBaseTransposed[(N_INSTANCES * f) + i] - centroids[posCentr + f];
							dist = mad(dif, dif, dist);
						}
					}

					if (dist < minDist) {
						minDist = dist;
						selectCentroid = k;
					}
				}

				distCentroids[i] = minDist;
				atomic_inc(&samples_in_k[selectCentroid]);

				if (mapping[i] != selectCentroid) {
					mapping[i] = selectCentroid;
				}
			}

			// Syncpoint
			barrier(CLK_LOCAL_MEM_FENCE);

			// Update the position of the centroids
			for (int kf = localId; kf < totalCoord; kf += localSize) {
				int k = kf / N_FEATURES;
				int f = kf - (k * N_FEATURES); // kf % N_FEATURES
				if (chromosome[f]) {
					float sum = 0.0f;
					for (int i = 0; i < N_INSTANCES; ++i) {
						if (mapping[i] == k) {
							sum += dataBase[(N_FEATURES * i) + f];
						}
					}
					centroids[kf] = sum / samples_in_k[k];
				}
			}

			// Syncpoint
			barrier(CLK_LOCAL_MEM_FENCE);
		}

		/************ Minimize the within-cluster and maximize Inter-cluster sum of squares (WCSS and ICSS) *************/

		if (localId == 0) {
			float sumWithin = 0.0f;
			float sumInter = 0.0f;

			// Within-cluster
			for (int i = 0; i < N_INSTANCES; ++i) {
				sumWithin += sqrt(distCentroids[i]);
			}

			// Inter-cluster
			for (int posCentr = 0; posCentr < totalCoord; posCentr += N_FEATURES) {
				for (int i = posCentr + N_FEATURES; i < totalCoord; i += N_FEATURES) {
					float sum = 0.0f;
					for (int f = 0; f < N_FEATURES; ++f) {
						if (chromosome[f]) {
							float dif = centroids[posCentr + f] - centroids[i + f];
							sum = mad(dif, dif, sum);
						}
					}
					sumInter += sqrt(sum);
				}
			}

			// First objective function (Within-cluster sum of squares (WCSS))
			pop[ind].fitness[0] = sumWithin;

			// Second objective function (Inter-cluster sum of squares (ICSS))
			pop[ind].fitness[1] = sumInter;

			// Third objective function (Number of selected features)
			//pop[ind].fitness[2] = (float) nSelFeatures;
		}
	}
}