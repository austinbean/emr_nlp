####### Notes for New User:
	# Change f_path to filepath of csv file with data
	# Under FILES TO INCLUDE, change the filepaths to match your computer


using CSV
using DataFrames
using Flux
using Flux: onehot, onehotbatch, logitcrossentropy, reset!, throttle
using Statistics: mean
using Random
using Parameters: @with_kw
using Embeddings
using Functors
using Plots
using GR

f_path = "./data_labeled.csv"
#Change this to ("./data_labeled.csv")

# -- FILES TO INCLUDE -- #
include("./punctuation_strip.jl")
include("./rnn_embeddings.jl")

# -- Constants -- #
const embed_table = load_embeddings(GloVe)
const get_word_index = Dict(word=>ii for (ii,word) in enumerate(embed_table.vocab))

# -- args-- #
@with_kw mutable struct Args4
    lr::Float64 = 1e-3     # Learning rate 
    N::Int = 3             # Number of perceptrons in hidden layer
    embed_len::Int = 50    # Length of vector per each word embedding
    test_len::Int = 100    # Number of unique words in test data 
    word_list_len::Int = 0 # Total number of unique words
    vocab::Array{String, 1} = []  #All the words in the training data
    throttle::Int = 1     # throttle timeout
end

# -- Helper Functions --#
# write to take a delimiter, but return a vector of strings, not substrings
function s_split(x)
    return convert(Array{String,1}, split(x))
end

function get_embedding(word)
    ind = get_word_index[word]
    emb = embed_table.embeddings[:,  ind]
    return emb
end

function rowParser(s,d)
    #for every word, using key " ", add to dictionary
    a = split(s, " ")
    for word in a
        modWord = lowercase(word)
        modWord = string_cleaner(modWord)
        if haskey(d, modWord)
            d[modWord] += 1
        else
            d[modWord] = 1
        end
    end
    return nothing
end 

function getWords(array, d)
    for row in array #put all of the words into the dictionary
        rowParser(row, d)
    end
    return d
end    

# --  Recurrent Neural Network Functions -- #
function load_data(file_path)
    df = CSV.File(file_path) |> DataFrame! 
    col1 = df[:, 1] 
    col2 = df[:, 2]
    args = Args4()
    
    dict = Dict{String, Integer}()
    #fill dictionary with words from df
    getWords(col1, dict)
    
    #add a string to our dictionary that will be placeholder for words found in testing never seen before
    dict["<unk>"] = 0 
    
    words = collect(skipmissing(keys(dict)))
    args.vocab = collect(skipmissing(keys(dict))) 
    #println(typeof(args.vocab))
    args.word_list_len = length(words)
    
    #Sentences not words
    items = []
    for s in col1
        push!(items, s_split(s))
    end
    #println(items[1])
    #for loops: go through each sentence (which is broken down into individual words), go through classification
    dataset = [(onehotbatch(s, words, "<unk>"), c) 
                for (s, c) in zip(items, col2)] |> shuffle
    
    
    train, test = dataset[1:end-args.test_len], dataset[end-args.test_len+1:end]
    return train, test, args
end

function build_model(args)
    scanner = Chain(Embed(args.vocab, args.embed_len, embed_table), LSTM(args.embed_len, args.N))
    encoder = Dense(args.N, 1, identity)
    return scanner, encoder
end

function model(x, scanner, encoder)
    state = scanner.(x.data)[end]
    reset!(scanner) #reset hidden states so each sentence gets own treatment
    encoder(state)
end


function training_model(file_path)
    # Load Data
    train_data, test_data, arg = load_data(file_path)
    #create variables for CSV file to track progress
    rounds = 15  
    round_num = []
    loss_values = []
  
    @info("Constructing Model...")
    scanner, encoder = build_model(arg)

    loss(x, y) = Flux.mse(model(x, scanner, encoder), y)
    
    #logitcrossentropy for discrete (classification), MSE for continuous (regression/predictive)
    testloss() = mean(loss(t...) for t in test_data)
    #evalcb = () -> @show testloss()
    
    opt = ADAM(arg.lr)
    ps = params(scanner, encoder)
    
    println(string(rounds, " *** epochs")) 
    @info("Training...")
    #train more than once, put in loop
    for i = 1:rounds
        push!(loss_values, testloss()) #error called here
        push!(round_num, i)
        println(i)
        Flux.train!(loss, ps, train_data, opt)
        println(model(train_data[1][1], scanner, encoder), " ", train_data[1][2])
    end
    
    
    prediction_arr = getindex.(test_data, 1)
    model_prediction = []
    for i in 1:length(test_data)
        append!(model_prediction,  model(prediction_arr[i], scanner, encoder))
    end
    real = getindex.(test_data, 2)
    
    #Create histogram of Results vs Model Prediction -> changes this to  percent accurate later
    histogram(model_results.Reality, bins = 10:5:maximum(model_results.Reality), label  = "Real Values")
    display(histogram!(model_results.Prediction, bins = 0:1:(maximum(model_results.Prediction)+1), 
            label = "Model Predictions", xlabel = "Value (Ounces of Milk)", ylabel = "Number of Occurances", 
            title = "RNN Model Predictions vs Real Value"))
    
    #Export csv of data of predictions for histogram for outside-function use
    modelAccuracy = DataFrame()
    modelAccuracy.Prediction = model_prediction
    modelAccuracy.Reality = real
    CSV.write("./modelResults.csv", modelAccuracy)
    
    #Export csv for loss values for each training round
    df = DataFrame()
    df.EpochNum = round_num
    df.LossVals = loss_values
    CSV.write("./test_loss.csv", df)
    
    #Export csv with the lowest root mean squared value from training
    export_RMSE = DataFrame()
    export_RMSE.RMSE_val = minimum(loss_df.LossVals)
    CSV.write("./rmse.csv", export_RMSE)

end

# --  Training Model --  # 
training_model(f_path)