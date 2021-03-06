/**
 * @file config.h
 * @author Juan José Escobar Pérez
 * @date 14/02/2016
 * @brief Header file for extracting the program configuration parameters from command-line or from the XML configuration. Also, internal parameters are considered
 *
 */

#ifndef CONFIG_H
#define CONFIG_H

using namespace std;

/********************************* Includes *******************************/

#include <stdio.h> // Lot of things...
#include <string> // string

/******************************** Structures ******************************/

/**
 * @brief Structure containing the configuration parameters
 */
typedef struct Config {


	/********************************* Internal parameters ********************************/

	/**
	 * @brief The parameter indicating the number centroids (clusters)
	 */
	int nCentroids;

	/**
	 * @brief The parameter indicating the number of maximum iterations for the convergence of K-means
	 */
	int maxIterKmeans;


	/**
	 * @brief The parameter indicating the number of individuals
	 */
	int populationSize;


	/**
	 * @brief The parameter indicating the total number of individuals (parents and children)
	 */
	int totalIndividuals;


	/**
	 * @brief The parameter indicating the size of the pool (the half of the population size)
	 */
	int poolSize;


	/**
	 * @brief The parameter indicating the number of features of the database
	 */
	int nFeatures;


	/**
	 * @brief The parameter indicating the number of instances of the database
	 */
	int nInstances;


	/**
	 * @brief The parameter indicating the number of objectives
	 */
	unsigned char nObjectives;


	/**
	 * @brief The parameter indicating if the program is in benchmark mode
	 */
	bool benchmarkMode;


	/********************************* XML/command-line parameters ********************************/

	/**
	 * @brief The parameter indicating the number of executions of the program (only for benchmarks)
	 */
	int nExecutions;


	/**
	 * @brief The parameter indicating the name of the file containing the database
	 */
	string dataBaseFileName;


	/**
	 * @brief The parameter indicating the number of generations to generate
	 */
	int nGenerations;


	/**
	 * @brief The parameter indicating the maximum number of features initially set to "1"
	 */
	int maxFeatures;


	/**
	 * @brief The parameter indicating the number of individuals competing in the tournament
	 */
	int tourSize;


	/**
	 * @brief The parameter indicating the name of the file containing the fitness of the individuals in the first Pareto front
	 */
	string dataFileName;


	/**
	 * @brief The parameter indicating the name of the file containing the gnuplot code for data display
	 */
	string plotFileName;


	/**
	 * @brief The parameter indicating the name of the file containing the image with the data (graphic)
	 */
	string imageFileName;


	/**
	 * @brief The parameter indicating the number of OpenCL devices that will run the program
	 */
	int nDevices;


	/**
	 * @brief The parameter indicating the devices name that will run the program
	 */
	string *devices;


	/**
	 * @brief The parameter indicating the number of compute units of each device that will run the program
	 */
	string *computeUnits;


	/**
	 * @brief The parameter indicating the number of work-items (threads) per compute unit of each device that will run the program
	 */
	string *wiLocal;


	/**
	 * @brief The parameter indicating the maximum number of individuals to be processed in a single execution of the kernel
	 */
	int maxIndividualsOnGpuKernel;


	/**
	 * @brief The parameter indicating the name of the file containing the kernels with the OpenCL code
	 */
	string kernelsFileName;	


	/********************************* Methods ********************************/

	/**
	 * @brief The constructor with parameters
	 * @param argv The command-line parameters
	 * @param argc Number of arguments
	 * @return An object containing all the configuration parameters
	 */
	Config(const char **argv, const int argc);

} Config;


/**
 * @brief Split a string into tokens separated by commas (,)
 * @param str The string to be split
 * @param nSplit The definitive number of obtained tokens
 * @return A pointer containing the tokens
 */
string* split(const string str, int *nSplit);

#endif