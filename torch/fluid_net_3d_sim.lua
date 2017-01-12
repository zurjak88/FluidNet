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

-- Simulation script to run a 3D model for a particular scene and dump the
-- results to file (for rendering in Blender).
--
-- We give a single boundary condition example of a plume from the bottom of
-- the grid with otherwise open boundary conditions.
--
-- The geometry in the scene is controlled through the 'loadVoxelModel'
-- parameter.
--
-- The output is a sequence of .vbox files in the CNNFluids/blender folder.
-- These files are then loaded into blender for rendering.

local tfluids = require('tfluids')
local paths = require('paths')
dofile("lib/include.lua")
dofile("lib/save_parameters.lua")
dofile("lib/demo_utils.lua")
dofile("lib/geom_export.lua")
dofile("lib/geom_import_binvox.lua")

-- ****************************** Define Config ********************************
local conf = torch.defaultConf()
conf.batchSize = 1
conf.loadModel = true
conf.visualizeData = true
conf.saveData = true
conf = torch.parseArgs(conf)  -- Overwrite conf params from the command line.
assert(conf.batchSize == 1, 'The batch size must be one')
assert(conf.loadModel == true, 'You must load a pre-trained model')

-- ****************************** Select the GPU *******************************
cutorch.setDevice(conf.gpu)
print("GPU That will be used:")
print(cutorch.getDeviceProperties(conf.gpu))

-- ***************************** Create the model ******************************
conf.modelDirname = conf.modelDir .. '/' .. conf.modelFilename
local mconf, model = torch.loadModel(conf.modelDirname)
mconf.vorticityConfinementAmp = 0.8
mconf.buoyancyScale = 1
model:cuda()
print('==> Loaded model from: ' .. conf.modelDirname)
torch.setDropoutTrain(model, false)
assert(not mconf.twoDim, 'The model must be 3D')
print('    mconf:')
print(torch.tableToString(mconf))

-- *************************** Define some variables ***************************
local res = 128
local batchCPU = {
    pDiv = torch.FloatTensor(conf.batchSize, 1, res, res, res):fill(0),
    UDiv = torch.FloatTensor(conf.batchSize, 3, res, res, res):fill(0),
    geom = torch.FloatTensor(conf.batchSize, 1, res, res, res):fill(0),
    density = torch.FloatTensor(conf.batchSize, 3, res, res, res):fill(0)
}
print("running simulation at resolution " .. res .. "^3")
-- *************************** Load a model into geom **************************
local voxels = {}
local outDir
if conf.loadVoxelModel ~= "none" then
  if conf.loadVoxelModel == "arc" then
    voxels = tfluids.loadVoxelData('../voxelizer/voxels_demo/Y91_arc_64.binvox')
    --This lines up the arc correctly
    tfluids.flipDiagonal(voxels.data, 2)
    tfluids.flipDiagonal(voxels.data, 0)
    outDir = '../blender/arch_render/'
  elseif conf.loadVoxelModel == "bunny" then
    voxels = tfluids.loadVoxelData(
      '../voxelizer/voxels_demo/bunny.capped_64.binvox')
    outDir = '../blender/bunny_render/'
  else
    error('Bad conf.loadVoxelModel value')
  end
  voxels.data = tfluids.expandVoxelsToDims(res, res, res, voxels.data)
  tfluids.moveVoxelCentroidToCenter(voxels.data)
  voxels.dims = {res, res, res}
  local bb = tfluids.calculateBoundingBox(voxels.data)
  voxels.min = bb.min
  voxels.max = bb.max

  batchCPU.geom[{{},1}] = voxels.data:view(1, res, res, res)
else
  outDir = '../blender/mushroom_cloud_render/'
end
--*****************************************************************************
local batchGPU = {}
for key, value in pairs(batchCPU) do
  batchGPU[key] = value:cuda()
end
local frameCounter = 1
local simulationTimeSec = 102.4
local outputDecimation = 4  -- Set to 1 to disable. Output every 4 frames.

local numFrames = simulationTimeSec / mconf.dt
print('Simulating with dt = ' .. mconf.dt)
print('Saving ever ' .. outputDecimation .. ' frames')
print('Simulating for ' .. numFrames .. ' frames (' .. simulationTimeSec ..
      'sec)')

-- ****************************** DATA FUNCTIONS *******************************
-- Set up a plume boundary condition.
local color = {1, 1, 1}
local uScale = 1  -- 0 turns it off and will only use buoyancy.
local rad = 0.15
tfluids.createPlumeBCs(batchGPU, color, uScale, rad)
--[[
-- You can measure the max velocity of the training set using:
dofile("lib/include.lua")
tr = torch.load("../data/datasets/preprocessed_output_current_3d_geom_tr.bin")
UMax = {}
for r = 1, #tr.runs do
  torch.progress(r, #tr.runs)
  for i = 1, tr.runs[r].ntimesteps do
    local curUMax = 0
    local p, Ux, Uy, Uz = tr:getSample(conf.dataDir, r, i)
    curUMax = math.max(curUMax, Ux:abs():max())
    curUMax = math.max(curUMax, Uy:abs():max())
    curUMax = math.max(curUMax, Uz:abs():max())
    UMax[#UMax + 1] = curUMax
  end
end
UMax = torch.FloatTensor(UMax)
gnuplot.hist(UMax, 200)
--]]

-- ***************************** Create Voxel File ****************************
local densityFile, densityFilename, geomFile, geomFilename
if conf.saveData then
  densityFilename = (outDir .. '/density_output_' .. conf.modelFilename ..
                     '_dt' .. mconf.dt .. '.vbox')
  densityFile = torch.DiskFile(densityFilename,'w')
  densityFile:binary()
  densityFile:writeInt(res)
  densityFile:writeInt(res)
  densityFile:writeInt(res)
  densityFile:writeInt(numFrames)
  
  geomFilename = (outDir .. '/geom_output_' .. conf.modelFilename ..
                  '_dt' .. mconf.dt .. '.vbox')
  geomFile = torch.DiskFile(geomFilename,'w')
  geomFile:binary()
  geomFile:writeInt(res)
  geomFile:writeInt(res)
  geomFile:writeInt(res)
  geomFile:writeInt(1)
end

local hImage
if conf.visualizeData then
  local density = batchGPU.density:mean(2):squeeze()
  density = density:mean(1):squeeze()  -- Average along Z dimension.
  hImage = image.display{image = density, zoom = 512 / density:size(1),
                         gui = false, legend = 'density'}
end

-- ***************************** SIMULATION LOOP *******************************
for i = 1, numFrames do
  collectgarbage()
  print('Simulating frame ' .. i .. ' of ' .. numFrames)
  
  tfluids.simulate(conf, mconf, batchGPU, model, false)
  -- Result is now on the GPU.

  local p, U, geom, density = tfluids.getPUGeomDensityReference(batchGPU)

  if conf.saveData then
    if i == 1 then
      geomFile:writeFloat(
          geom:squeeze():permute(3, 2, 1):float():contiguous():storage())
      print('  ==> Saved geom to ' .. geomFilename)
    end
    if math.fmod(i, outputDecimation) == 0 then
      -- Save greyscale density (so mean across RGB).
      densityFile:writeFloat(density:mean(2):squeeze():permute(
          3, 2, 1):float():contiguous():storage())
      print('  ==> Saved density to ' .. densityFilename)
    end
  end

  if conf.visualizeData then
    local density = batchGPU.density:mean(2):squeeze()
    density = density:mean(1):squeeze():sqrt()
    image.display{image = density, zoom = 512 / density:size(1),
                  gui = false, legend = 'density', win = hImage}
  end
end

if conf.saveData then
  densityFile:close()
  geomFile:close()
end

