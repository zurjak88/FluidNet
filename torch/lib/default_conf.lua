-- Copyright 2016 Google Inc, NYU.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- conf table with default parameters.
--
-- Everything here can be modified through the command line (see README.md for
-- more info). Note: newModel is actually moved out of the conf table at
-- model creation and becomes the "mconf" table. This table is saved to disk
-- on every epoch so that simulations can be paused and restarted.

function torch.defaultConf()
  -- Please keep this table in alphabetical order.
  local conf = {
    batchSize = 16,  -- Definitely depends heavily on model and dataset
    dataDir = '../data/datasets/',  -- Where the unprocessed data is stored.
    dataset = 'output_current_3d_model_sphere',  -- Default: 2D with geometry.
    gpu = 1,  -- Cuda GPU to use
    ignoreFrames = 0,  -- Ignore the first 'n' frames of each run
    -- lrEpochMults: pairs of {epoch, multiplier}. We will
    -- apply the specified multiplier to the learning rate at each epoch.
    lrEpochMults = {{epoch = math.huge, mult = 0.25}},
    loadModel = false,  -- set true when resuming training or evaluating
    --loadVoxelModel: used in fluids_net_3d_sim.lua only. Options:  'none |
    -- arc | bunny'
    loadVoxelModel = 'none',
    maxEpochs = 5000,  -- Maximum number of epochs
    maxSamplesPerEpoch = math.huge,  -- For debugging.
    modelDir = '../data/models/',
    modelFilename = 'conv_model',  -- Output model file name
    newModel = {
      addBatchNorm = false,
      -- addPressureSkip: If true add a pressure skip connection.
      addPressureSkip = false,
      -- advectionMethod: options are 'euler', 'rk2', 'maccormack'
      advectionMethod = 'rk2',
      banksJoinStage = 3,  -- Join BEFORE this stage.
      banksAggregateMethod = 'add',  -- options are 'concat' and 'add'
      banksNum = 1,  -- Number of parallel resolution banks (1 == disable).
      banksSplitStage = 1,  -- Split BEFORE this stage.
      banksWeightShare = true,
      batchNormAffine = true,  -- ignored if addBatchNorm == false.
      batchNormEps = 1e-4,  -- ignored if addBatchNorm == false.
      batchNormMom = 0.1,  -- ignored if addBatchNorm == false.
      -- bndType: Defines the set boundary type method when updating velocity
      -- field (done after almost every step in the simulator). Options are:
      -- 'Ave', 'None', 'Zero'.
      bndType = 'Ave',
      -- buoyancyScale: Buoyancy force scale. Set to 0 to disable. 
      buoyancyScale = 0,
      -- dt: default simulation timestep. We will check this against manta
      -- data when training.
      dt = 0.1,
      -- gradNormThreshold: if the L2 norm of the gradient vector goes above
      -- the threshold then we will re-scale it to the threshold value.
      -- This is vitally important in removing outliers.
      gradNormThreshold = 1,
      -- inputChannels: Specify which inputs will be sent to the projection
      -- network.
      inputChannels = {
        div = true,
        geom = true,
        pDiv = true,
        UDiv = false,
      },
      lossFunc = 'fluid',  -- Only fluid is supported for now.
      lossFuncScaleInvariant = false,  -- If true then use Eigen's scale inv MSE
      lossPLambda = 0,
      lossULambda = 0,
      lossDivLambda = 1,
      -- longTermDivLambda: Set to 0 to disable (or set longTermDivNumSteps to
      -- nil).
      longTermDivLambda = 0.25,
      -- longTermDivNumSteps: We want to measure what the divergence is after
      -- a set number of steps for each training and test sample. Set table
      -- to nil to disable, (or set longTermDivLambda to 0).
      longTermDivNumSteps = {4, 16},
      -- longTermDivProbability is the probability that longTermDivNumSteps[1] 
      -- will be taken, otherwise longTermDivNumSteps[2] will be taken with
      -- probability of 1 - longTermDivProbability.
      longTermDivProbability = 1.0,
      -- optimizationMethod: available options: 'sgd', 'adam', 'adagrad',
      -- 'lbfgs' (requires full batch not mini batches)
      modelType = 'default',  -- Choices are 'default', 'yang', 'tog'
      nonlinType = 'relu',  -- Choices are: 'relu', 'relu6', 'sigmoid'.
      normalizeInput = false,  -- If true, normalize by max(std(chan), thresh)
      normalizeInputChan = 'UDiv',  -- Which input channel to calculate std.
      normalizeInputThrehsold = 0.01,  -- Don't normalize input noise.
      normalizeInputFunc = 'std',  -- Choices are: 'std' or 'norm' (l2).
      optimizationMethod = 'adam',
      optimState = {
        bestPerf = math.huge,
        learningRate = 0.0025,
        weightDecay = 0,  -- L2 regularization parameter
        momentum = 0.9,
        dampening = 0,
        learningRateDecay = 0,
        nesterov = false,
        epsilon = 0.0001,  -- epsilon value for ADAM optimizer.
        beta1 = 0.9,  -- beta1 value for ADAM optimizer.
        beta2 = 0.999,  -- beta2 value for ADAM optimizer.
      },
      poolType = 'avg', -- avg or max.
      -- vorticityConfinementAmp: The vorticity confinement scale value.
      -- Set to 0 to disable vorticity confinement.
      vorticityConfinementAmp = 0.05,
    },
    numDataThreads = 8,  -- To amortize the cost of data loading / processing.
    profile = false,  -- Requires ProFi.
    profileFPROPTime = 0,  -- In sec. Set to zero to disable profiling.
    resumeTraining = false,
    train = true,  -- perform training (otherwise just evaluate)
    trainPerturb = {
      flipProb = 0.5,
      on = false,  -- Whether or not to preturb training data.
      rotation = 0,  -- In degrees. NOT SUPPORTED.
      scale = 0,  -- Percentage. NOT SUPPORTED.
      -- timeScaleSigma: controls artificial dt inflation when calculating long
      -- term divergence. Must be >= 0 (set to 0 to disable).
      -- The random dt will be 'dt * (1 + abs(randn(0, timeScaleSigma)))' (i.e.
      -- we mostly pick scales that are close to dt.
      timeScaleSigma = 1,
      transPix = 0,  -- NOT SUPPORTED.
    },
  }
  return conf
end

