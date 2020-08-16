using CSV
using DataFrames
using Query
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Flux.Data: DataLoader
using Embeddings
using Embeddings: EmbeddingTable
using Functors
using Statistics: mean
using Random
using Parameters: @with_kw
using Plots

@with_kw mutable struct Args
    lr::Float64 = 1e-3      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	N::Int = 100            # Number of perceptrons in hidden layer - free parameter
	throttle::Int = 5       # throttle timeout
    test_d::Int = 300       # length of the testing set.
    maxw::Int = 30          # maximum number of words in a sentence
    embeddim::Int = 50      # dimension of embedding
    tt::Float64 = 0.7       # fraction of data train
    epos::Int64 = 30       # epochs
end

#Set WD
#cd("/Users/mousaghannnam/Documents/Data Science/sumr2020/Models/CNN")

#Include access to data loading functions
include("./cnn_dataloader.jl")
include("./punctuation_strip.jl")
include("./embeddings_layer.jl")

function calculateDenseParam(sentenceMaxLength)
	l1w = floor((sentenceMaxLength - 2) / 2)
	l2w = floor((l1w - 2) / 4)
	denseDim = l2w * 5 * 8
	return convert(Int64,denseDim)
end


function model(args, c1::Int64)
    # TODO - this may change depending on the longest sentence in the set - see Dense layer
    return m = Chain(Conv((3,5), 1=>128),                # size here is 28 x 46 x 128 x 701
            MaxPool((2,2)),                     # size here is 14 x 23 x 128 x 701
            Conv((3,3), 128=>8, relu),          # size here is 12 x 21 x 8 x 701,
            MaxPool((4,4)),                     # size here is 3 x 5 x 8 x 701
            x->reshape(x,:, size(x,4)),         # size here is 120 x 701,  = 3 x 5 x 8
            Dense(c1,1, identity),             # TODO: this dim will change! size now is 1 x 701 - one prediction per observation.
            x->reshape(x, size(x,2), size(x,1)) # just a transpose
            )
end


#= function plotResults(df::DataFrame)
    plotly() #Create backend
    p1 = plot(df[:,1], markersize = 2, label = "Training", xlabel = "Number of Times Trained",ylabel = "Loss Function (MSE)")
	p2 = plot(df[:,2], markersize = 2, label = "Training", xlabel = "Number of Times Trained",ylabel = "Loss Function (RMSE)")
	h1 = histogram(m(tsd.data[1]),tsd.data[2], xlabel = "Food Value", ylabel = "Number of Occurences")
	CSV.write("cnn_results.csv", myResults)
	plotResults(p1,p2,h1, layout = (3,1))
	savefig(p1, "./CNN_test_mse.pdf")
	savefig(p2, "./CNN_test_rmse.pdf")
	savefig(h1, "./CNN_test_mhistogram.pdf")
end =#



function Run()
    trd, tsd, arr = LoadDataCNN()
    c1 = calculateDenseParam(arr.maxw)
    m = model(arr, c1)
    loss(x,y) = Flux.mse(m(x), y)
    println(loss(trd.data[1], trd.data[2]))
    parms = Flux.params(m)
    testloss() = Flux.mse(m(tsd.data[1]), tsd.data[2])
	rmse_func() = sqrt(Flux.mse(m(tsd.data[1]), tsd.data[2]))
    evalcb = () -> @show testloss()
    opt = ADAM(arr.lr)
    myResults = DataFrame()

    # temp = Array{Float64,1}
    temp_mse = Float64[]
	temp_rmse = Float64[]
    for i = 1:2
        println(i)
        Flux.train!(loss, parms, trd, opt, cb = throttle(evalcb, 1)) #
        push!(temp_mse, testloss())
		push!(temp_rmse, rmse_func())
    end
    myResults.test_loss_mse = temp_mse
    myResults.temp_rmse = temp_rmse
    
    function plotResults(df::DataFrame)
        plotly() #Create backend
        p1 = plot(df[:,1], markersize = 2, label = "Training", xlabel = "Number of Times Trained",ylabel = "Loss Function (MSE)")
        p2 = plot(df[:,2], markersize = 2, label = "Training", xlabel = "Number of Times Trained",ylabel = "Loss Function (RMSE)")
        # NB: tsd does not exist outside the scope of Run()
        h1 = histogram(m(tsd.data[1]),tsd.data[2], xlabel = "Food Value", ylabel = "Number of Occurences")
        CSV.write("./cnn_results.csv", myResults)
        plot(p1,p2,h1, layout = 3)
        savefig(p1, "./CNN_test_mse.png")
        savefig(p2, "./CNN_test_rmse.png")
        savefig(h1, "./CNN_test_histogram.png")
    end

    plotResults(myResults)
end

Run()
