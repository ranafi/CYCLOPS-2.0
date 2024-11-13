# CYCLOPS 2.0 Template
# This CYCLOPS 2.0 template will guide you through set up.
#   Workflow
# 1.    load required packages
# 2.    define path to your expression data
# 3.    load expression data
# 4.    define path to your seed gene list
# 6.    define path to your output directory
# 8.    initialize training parameters
# 9.    spawn multiple processors for parallel computing
# 10.   train CYCLOPS
# 11.   store outputs
# 12.   calculate smoothness metric
# 13.   reapply CYCLOPS to sample subsets
# 14.   store reapplied outputs
# 15.   calculate reapplied smoothness metric
# 16.   calculate stat error


########################################################################
# 1. Load Required Packages
# These packages are required at the top level. Other required packages are loaded within the CYCLOPS module.
# CSV:          Provides fast, flexible reader & writer for delimited text files in various formats.
# DataFrames:   To store data in dataframe format (used in conjunction with CSV).
# Random:       Support for generating random numbers.
# Revise:       Tracks source code changes and incorporates the changes to a running Julia session.
# Distributed:  Tools for distributed parallel processing.
# addprocs:     Launches workers using the in-built LocalManager which only launches workers on the local host.
# rmprocs:      Remove the specified workers.
using CSV, DataFrames, Random, Revise
using Distributed: addprocs, rmprocs
########################################################################


########################################################################
# 2. Define Path to Expression Data
data_path = joinpath(homedir(), "your/path/to/expression/data/file.csv")    # path to expression data   (.csv)
########################################################################


########################################################################
# 3. Load Expression Data
expression_data = CSV.read(data_path, DataFrame)                            # load expression data to a dataframe
########################################################################


########################################################################
# 4. Define Path to Seed Gene List
# You may or may not have stored your seed gene list to a csv file.
# If your seed gene list is stored to a csv file, define your path to said file here.
# Make note of the column header in the file, you'll need it in step 5.
# If you did not store your seed gene list to a csv file you can skip this step and go to setp 5.
seed_path = joinpath(homedir(), "your/path/to/seed/gene/file.csv")          # path to seed gene list    (.csv)
########################################################################


########################################################################
# 5. Load Seed Gene List
# If your seed gene list is stored to a csv file, this will read in the file as a dataframe.
# This code assumes that the column header of the seed gene file is 'Gene_Symbols'
# If the column header of your seed gene list file is not 'Gene_Symbols', replace it with your column header.
# Here are some examples of changing the selected column header
# e.g. seed_genes = CSV.read(seed_path, DataFrame).symbols
# e.g. seed_genes = CSV.read(seed_path, DataFrame).x
# e.g. seed_genes = CSV.read(seed_path, DataFrame).x1
# e.g. seed_genes = CSV.read(seed_path, DataFrame).ID
# e.g. seed_genes = CSV.read(seed_path, DataFrame).GENEID
seed_genes = CSV.read(seed_path, DataFrame).Gene_Symbols
########################################################################


########################################################################
# 4. Define Path to Output Directory
output_path = joinpath(homedir(), "your/path/to/desired/output/directory")  # path to output directory  (./)
########################################################################


########################################################################
########################################################################


########################################################################
seed_genes = [] # vector of strings containing gene symbols matching the format of gene symbols in the first column of the expression_data dataframe.

sample_ids_with_collection_times = [] # sample ids for which collection times exist
sample_collection_times = [] # colletion times for sample ids

if ((length(sample_ids_with_collection_times)+length(sample_collection_times))>0) && (length(sample_ids_with_collection_times) != length(sample_collection_times))
    error("ATTENTION REQUIRED! Number of sample ids provided (\'sample_ids_with_collection_times\') must match number of collection times (\'sample_collection_times\').")
end

# make changes to training parameters, if required. Below are the defaults for the current version of cyclops.
training_parameters = Dict(:regex_cont => r".*_C",			# What is the regex match for continuous covariates in the data file
:regex_disc => r".*_D",							# What is the regex match for discontinuous covariates in the data file

:blunt_percent => 0.975, 						# What is the percentile cutoff below (lower) and above (upper) which values are capped

:seed_min_CV => 0.14, 							# The minimum coefficient of variation a gene of interest may have to be included in eigen gene transformation
:seed_max_CV => 0.9, 							# The maximum coefficient of a variation a gene of interest may have to be included in eigen gene transformation
:seed_mth_Gene => 10000, 						# The minimum mean a gene of interest may have to be included in eigen gene transformation

:norm_gene_level => true, 						# Does mean normalization occur at the seed gene level
:norm_disc => false, 							# Does batch mean normalization occur at the seed gene level
:norm_disc_cov => 1, 							# Which discontinuous covariate is used to mean normalize seed level data

:eigen_reg => true, 							# Does regression again a covariate occur at the eigen gene level
:eigen_reg_disc_cov => 1, 						# Which discontinous covariate is used for regression
:eigen_reg_exclude => false,					# Are eigen genes with r squared greater than cutoff removed from final eigen data output
:eigen_reg_r_squared_cutoff => 0.6,				# This cutoff is used to determine whether an eigen gene is excluded from final eigen data used for training
:eigen_reg_remove_correct => false,				# Is the first eigen gene removed (true --> default) or it's contributed variance of the first eigne gene corrected by batch regression (false)

:eigen_first_var => false, 						# Is a captured variance cutoff on the first eigen gene used
:eigen_first_var_cutoff => 0.85, 				# Cutoff used on captured variance of first eigen gene

:eigen_total_var => 0.85, 						# Minimum amount of variance required to be captured by included dimensions of eigen gene data
:eigen_contr_var => 0.05, 						# Minimum amount of variance required to be captured by a single dimension of eigen gene data
:eigen_var_override => true,					# Is the minimum amount of contributed variance ignored
:eigen_max => 5, 								# Maximum number of dimensions allowed to be kept in eigen gene data

:out_covariates => true, 						# Are covariates included in eigen gene data
:out_use_disc_cov => true,						# Are discontinuous covariates included in eigen gene data
:out_all_disc_cov => true, 						# Are all discontinuous covariates included if included in eigen gene data
:out_disc_cov => 1,								# Which discontinuous covariates are included at the bottom of the eigen gene data, if not all discontinuous covariates
:out_use_cont_cov => false,						# Are continuous covariates included in eigen data
:out_all_cont_cov => true,						# Are all continuous covariates included in eigen gene data
:out_use_norm_cont_cov => false,				# Are continuous covariates Normalized
:out_all_norm_cont_cov => true,					# Are all continuous covariates normalized
:out_cont_cov => 1,								# Which continuous covariates are included at the bottom of the eigen gene data, if not all continuous covariates, or which continuous covariates are normalized if not all
:out_norm_cont_cov => 1,						# Which continuous covariates are normalized if not all continuous covariates are included, and only specific ones are included

:init_scale_change => true,						# Are scales changed
:init_scale_1 => false,							# Are all scales initialized such that the model sees them all as having scale 1
                                                # Or they'll be initilized halfway between 1 and their regression estimate.

:train_n_models => 80, 							# How many models are being trained
:train_μA => 0.001, 							# Learning rate of ADAM optimizer
:train_β => (0.9, 0.999), 						# β parameter for ADAM optimizer
:train_min_steps => 1500, 						# Minimum number of training steps per model
:train_max_steps => 2050, 						# Maximum number of training steps per model
:train_μA_scale_lim => 1000, 					# Factor used to divide learning rate to establish smallest the learning rate may shrink to
:train_circular => false,						# Train symmetrically
:train_collection_times => true,						# Train using known times
:train_collection_time_balance => 1.0,					# How is the true time loss rescaled
# :train_sample_id => sample_ids_with_collection_times,
# :train_sample_phase => sample_collection_times,

:cosine_shift_iterations => 192,				# How many different shifts are tried to find the ideal shift
:cosine_covariate_offset => true,				# Are offsets calculated by covariates

:align_p_cutoff => 0.05,						# When aligning the acrophases, what genes are included according to the specified p-cutoff
:align_base => "radians",						# What is the base of the list (:align_acrophases or :align_phases)? "radians" or "hours"
:align_disc => false,							# Is a discontinuous covariate used to align (true or false)
:align_disc_cov => 1,							# Which discontinuous covariate is used to choose samples to separately align (is an integer)
:align_other_covariates => false,				# Are other covariates included
:align_batch_only => false,
# :align_samples => sample_ids_with_collection_times,
# :align_phases => sample_collection_times,
# :align_genes => Array{String, 1},				# A string array of genes used to align CYCLOPS fit output. Goes together with :align_acrophases
# :align_acrophases => Array{<: Number, 1}, 	# A number array of acrophases for each gene used to align CYCLOPS fit output. Goes together with :align_genes

:X_Val_k => 10,									# How many folds used in cross validation.
:X_Val_omit_size => 0.1,						# What is the fraction of samples left out per fold

:plot_use_o_cov => true,
:plot_correct_batches => true,
:plot_disc => false,
:plot_disc_cov => 1,
:plot_separate => false,
:plot_color => ["b", "orange", "g", "r", "m", "y", "k"],
:plot_only_color => true,
:plot_p_cutoff => 0.05)

Distributed.addprocs(length(Sys.cpu_info()))
@everywhere include(path_to_cyclops)

# real training run
training_parameters[:align_genes] = CYCLOPS.human_homologue_gene_symbol[CYCLOPS.human_homologue_gene_symbol .!= "RORC"]
training_parameters[:align_acrophases] = CYCLOPS.mouse_acrophases[CYCLOPS.human_homologue_gene_symbol .!= "RORC"]
eigendata, modeloutputs, correlations, bestmodel, parameters = CYCLOPS.Fit(expression_data, seed_genes, training_parameters)
CYCLOPS.Align(expression_data, modeloutputs, correlations, bestmodel, parameters, output_path)
