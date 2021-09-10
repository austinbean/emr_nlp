
using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Statistics: mean
using Random: shuffle, seed! 
using Parameters: @with_kw
#using Plots 
using Tables 
using Dates
using Transformers
using Transformers.Basic
using Transformers.Pretrain

include("/Users/austinbean/Desktop/programs/emr_nlp/punctuation_strip.jl")
include("/Users/austinbean/Desktop/programs/emr_nlp/s_split.jl")
include("/Users/austinbean/Desktop/programs/emr_nlp/labeler.jl")


@with_kw mutable struct Args
    lr::Float64 = 1e-5      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	maxlen::Int = 79        # maximum length of a sentence
	N::Int = 1024           # Number of perceptrons in layer prior to classification
	throttle::Int = 1       # throttle timeout
	classes::Int = 5        # number of classes
	embed_dim::Int = 512    # dimension of hidden embedding.  
	heads::Int = 8          # transformer heads 
end




"""
`LoadData()`

This creates test and training data and returns them.  Also returns an instance of 'args' type
w/ the number of unique words in the data updated.

# TODO - use the BERT embeddings here.  
# TODO - classification within a few ounces might be a better task?  
# TODO - also... could use time information to figure out classification scheme?  this is a labeling task too.  
 fundamentally this is just a translation problem, though a weird one.
 sentence → number/category.

NB: might need to pad to the same length?  max length is 79 words

This can't be what I want... I have not tuned the embeddings at all yet.  
This so far has just loaded the embeddings, effectively. 

	#=
		# next steps recover the embeddings but maybe that's not the right strategy
		segment_indices = map( v-> [fill(1, length(v));2], s_split.(words))
		dat = map(x-> bert_model.embed((tok = x[1], segment = x[2] )) , zip(word_indices, segment_indices))
		tensors = map(x-> bert_model.transformers(x), dat)
		args.N = size(tensors[1],1) # number of inputs is dimension of layer.  
	=#

"""
function LoadData()
		# Load and clean 
	#xfile = CSV.read("./data_labeled.csv", DataFrame);

	# TODO - there is nothing called column 1, column 2.  col1 -> diet, col2 -> total_quantity 
	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :diet_text]));
	words = string_cleaner.(words) ;	      # regex preprocessing to remove punctuation etc. 
	mwords = maximum(length.(split.(words)))  # max length of sentence
	words = PadSentence.(words,mwords) #Pad sentences to max length
			# NB: BERT uses the last token to predict which sentence precedes another.  
	words = map( x->x*" <CLS>", words) ;   # add <CLS> to the end of every sentence.
	labels = filter( x-> !ismissing(x), xfile[!, :total_formula]);
	labels = labeler(labels) # bin into categories
	labels = convert(Vector{Int64}, labels[:,2]) # take category labels
	args = Args() # create an instance of the type
	#args.classes = 5
	#args.maxlen = mwords 
	#allwords = [unique( reduce(vcat, s_split.(words)) ); "[UNK]"; "<EOS>"; "<CLS>"]     # collect all unique words add an "<UNK>" symbol for unfamiliar words
	#nwords = size(allwords,1) 
	# args.test_d = convert(Int,floor(0.6*size(interim,1)))
	# train_data = interim[1:end-args.test_d]
	# test_data = interim[end-args.test_d+1:end]
	bert_model, wordpiece, tokenizer = pretrain"bert-uncased_L-12_H-768_A-12"
	vocab = Vocabulary(wordpiece)
	args.inpt_dim = vocab.siz                                                          # how many unique words are there?

		# maybe add the labels here.  
	word_indices = map( v-> [vocab(v[1]), v[2]], zip(s_split.(words), labels))
	# there should be a reshape or a convert here. 
		# very confusing that a straightforward Convert does not work??  
	w2 = map( v-> push!(vocab(v[1]), v[2]), zip(s_split.(words), labels))
	w3 = map( v -> reshape(v, 1, size(v,1)), w2)
	# Return args b/c nwords may have been updated.
		# change to train via epochs.
	#Flux.Data.DataLoader(ctrain, ltrain; batchsize=100, shuffle = true), Flux.Data.DataLoader(ctest, ltest), args
	# TODO - will this split train/test for me?  then can replace w interim.  
	# TODO - the LAST dimension in the data is treated as the observation dimension, so size(data,2) should index observations. 
	return word_indices, labels, args #Flux.Data.DataLoader( (interim, labels); batchsize=100, shuffle = true),  args
end 


function model_objects(args)	
		# positionembedding retuns a position embedding of dimension equal to the embedding dim
	pe = PositionEmbedding(args.embed_dim) # same dim an Embed, since they are added 
		# first argument is dimension of embedding 
		# second argument is number of words in vocab 
	@show args.inpt_dim
	embed = Embed(args.embed_dim, args.inpt_dim)
	# TODO - reshape this to make the output format correct?  
	function embedding(x)
		return embed(x, inv(sqrt(args.maxlen))) .+ pe(embed(x, inv(sqrt(args.maxlen))))
	end 

	function embedding2(x)
  		we = embed(x, inv(sqrt(512))) 
  		e = we .+ pe(we)
  		return e
	end
		# What are all of these arguments?  
			# first arg - input size / sentence length ? No. 
			# second arg - number of heads 
			# third arg - hidden layer size (for fully connected layer?)
			# fourth arg - hidden size of what??  "pwffn_size" - position_wise feed forward network
	encode_t1 = Transformer(args.embed_dim, args.heads, 64, 2048)
	encode_t2 = Transformer(args.embed_dim, args.heads, 64, 2048)
	linear = Positionwise(Dense(args.embed_dim, args.inpt_dim), logsoftmax)

# TODO - these have the wrong number of arguments?  Why?  
	decode_t1 = TransformerDecoder(args.embed_dim, args.heads, 64, 2048) 
	decode_t2 = TransformerDecoder(args.embed_dim, args.heads, 64, 2048) 

	# I guess I need both of these  
	function encoder_model(x)
		e = embedding(x)
		t1 = encode_t1(e)
		t2 = encode_t2(t1)
		l1 = linear(t2)
		return l1
	end 

	function decoder_model(x,m)
		e = embedding(x)
		t1 = decode_t1(e, m)
		t2 = decode_t2(t1, m)
		p = linear(t2)
 		return p
	end 

		# next step.  What role does encoded_sample play?   What is it?

	return encoder_model, decoder_model, pe, embed, embedding, encode_t1, encode_t2, linear 
end

#=

function loss(x, y)
  label = Basic.OneHotArray(length(vocab), y)
  label = smooth(label) #perform label smoothing
  enc = encoder_forward(x)
  probs = decoder_forward(y, enc)
  l = logkldivergence(label[:, 2:end, :], probs[:, 1:end-1, :])
  return l
end

	# segfault but why? not clear?  
function loss(x,y)
	label = onehot(y, unique(labels)) # NB: unique(labels) must exist
	encoded = encoder_model(x)
	probs = decoder_model(y,encoded)
	l = logkldivergence(label, probs)
end
=#


# function main()
# 	dat, labels, args = LoadData()
# 	labs = unique(labels)
# 	encoder_model, decoder_model, pos_emb, emb1, emb_func, enc_1, enc_2, lin_layer = model_objects(args)
# 	function loss(x,y)
# 		label = onehot(y, labs) # NB: unique(labels) must exist
# 		encoded = encoder_model(x)
# 		probs = decoder_model(x,encoded)
# 		# this surely won't immediately work.  
# 		l = logkldivergence(label, probs)
# 		return l
# 	end
# 	ps = params(pos_emb, decode_t1, decode_t2, emb1, enc_1, enc_2, lin_layer)
# 	# Need to add the data to the loss.  
# 	opt = ADAM(args.lr)
# 	testloss() = mean(loss()...)
# end 

# main()