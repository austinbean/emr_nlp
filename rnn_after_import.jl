# use rnn_diet.jl to define a function to import the data, then put an include statement at the top of this one.

module Runner

using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Statistics: mean
using Random: shuffle
using Parameters: @with_kw
using Plots 


 # /Users/austinbean/Desktop/programs/emr_nlp
include("./punctuation_strip.jl")
include("./s_split.jl")
include("./rnn_diet.jl")


"""
`build_model(args)`
Takes as an argument the parameters in the "args" type.  
Returns two things: a 'scanner' and an 'encoder'.  
Dimension of the input needs to be # of unique words, 
so Dense(args.inpt_dim) takes an 'args.inpt_dim' type 
argument, where in LoadData() this is updated to the number of words.  
This is passed back after updating w/in the LoadData() function.
"""
function build_model(args)
	scanner = Chain(Dense(args.inpt_dim, args.N, σ), LSTM(args.N, args.N), LSTM(args.N, args.N))
	encoder = Dense(args.N, 1, identity) # regression task - sum outputs and apply identity activation.
	return scanner, encoder 
end 



"""
`model(x, scanner, encoder)`
Scanner is applied to the data sequentially, then I take the LAST element.
so need to make sure scanner outputs a vector, since that is the input to encoder.
Needs to output args.N x 1 vector if the encoder is to make sense.
NB: must call reset!(scanner) after each call to scanner.  
Otherwise creates a matrix which is not conformable w/ later data elements.
	Question: which matrix?  Why?  
the number of COLUMNS created is: N_words x Dim_hidden state.  So I want the last **column**.  
Flux one-hot matrix has a field called data, which is an array of one-hot vectors. 
so this DOES matter
Accessing via .data seems to change the dims?  Doing scanner.(x.data) returns an array of 
N_elements rows and N_hidden_dim columns.  Then taking scanner.(x.data)[end] returns the LAST 
one of these rows, which is what I want.  
Note then you have to take encoder(state)[1] to access the scalar in the 1x1 record.
Otherwise an error in loss b/c you can't do: [float] - float.
"""
function model(x, scanner, encoder)
	state = scanner.(x.data)[end]     # the last column, so the last hidden state and feature.  
	reset!(scanner)                   # must be called before each new record
	encoder(state)[1]                 # this returns a vector of a single element...  annoying.  
end 

#=
annoyingly... batching the data means that train_data is an iterable of vectors,
but vectors do not have the field .data as above, so I get an error in training.  
=#


function RunIt()
    train_data, test_data,  argg = LoadData() # words, labels will be loaded
	epoc = 3
	@info("Constructing Model...")
	scanner, encoder = build_model(argg)     # NB: scanner and encoder have to be created first.  
	submod(x) = model(x, scanner, encoder)   # maybe this is a workaround?  This broadcasts 
	loss(x, y)=  Flux.mse(submod.(x),y)      # broadcasting the "sub-model" on the input x.
	@info("Initial Loss: ", loss(test_data.data[1], test_data.data[2]) )
	testloss() = loss(test_data.data[1], test_data.data[2])	
	opt = ADAM(argg.lr)
	ps = params(scanner, encoder)
	evalcb = () -> @show testloss()
	loss_v = Array{Float64,1}()
	for i = 1:epoc
		@info("At ", i)
		Flux.train!(loss, ps, train_data, opt, cb = throttle(evalcb, argg.throttle))
		push!(loss_v, testloss())
	end 
    # next step... predict, distribution of predictions, etc.  
end 

RunIt()

end 


#=

"Postestimation..."

	pred_vals = Array{Float32,1}()
	actual = Array{Float32,1}()
	for i in 1:length(test_data)
		push!(actual, convert(Float32, test_data.data[2][i]))
		push!(pred_vals, model(test_data.data[1][i], scanner, encoder))
	end 
	sv = convert(DataFrame, hcat(pred_vals, actual))	

	Plots.histogram(sv.x2, bins = 10:5:maximum(sv.x2), label  = "Real Values")
	Plots.histogram!(sv.x1, bins = 0:1:(maximum(sv.x1)+1), 
			label = "Model Predictions", 
			xlabel = "Value (Ounces)", 
			ylabel = "Number of Occurences", 
            title = "RNN Model Predictions vs Real Values")
	savefig("./hist1.png")	
	
	df1 = convert(DataFrame, hcat(loss_v, zeros(length(loss_v))))
	plot(df1.x1, [1:size(loss_v,1)], xlabel = "Number of Times Trained", ylabel = "Loss Function",
        title = "Plotting the Loss Function of the RNN Model", legend = false)
    savefig("./lossf.png")

	CSV.write("./t_l_1.csv", convert(DataFrame, hcat(loss_v, zeros(length(loss_v)))))


=#

