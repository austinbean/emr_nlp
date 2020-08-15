function LoadDataCNN()
	args = Args()

	myData = CSV.read("./data_labeled.csv") |> DataFrame!     #Load Data
	# CSV.read("./data_labeled.csv")

    #Clean Data
    words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), myData[!, :diet]));
    words = string_cleaner.(words) # regex preprocessing to remove punctuation etc.
    #Add EOS Symbol to end of each word

	#Parameter Setting
    maxlen = maximum(length.(split.(words))) #Maximum length of sentence
    nobs = size(words,1) #Number of observations
	args.maxw = maxlen

    padded_sentences = pad_sentence.(s_split.(words),maxlen) #Pad sentences to max length
    labels = filter( x-> !ismissing(x), myData[!, :total_quantity]); #Prepare labels
    allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]

    lexiconFreq = Counter(myData) #Table of word frequencies

    uniqueWords = collect(keys(lexiconFreq)) #Obtain the unique words
    uniqueWords = push!(uniqueWords, "<UNK>") #Add our unknown symbol to the list of words
    N = length(uniqueWords)

    args = Args()
    args.inpt_dim = N

    #Create oneHotVectors from these words
    oneHotWords = map(word -> Flux.onehotbatch(word, uniqueWords, "<UNK>"), padded_sentences)

    # embtable = load_embeddings(Word2Vec) # load the embeddings
    embeddim = args.embeddim

    embedLayer = Embed(uniqueWords, embeddim, embtable)
    sh1 = embedLayer.(oneHotWords)

    a1 = reduce(hcat, sh1) # makes 50 x (1002 x 30)
    b1 = reshape(a1, embeddim, 1, maxlen, nobs);
        # now the shape is right but the axes are wrong.
        # So permute dims: first dim is dimension of embedding (50) ⇒ map to 2nd dim (this is the height)
        # Second dimension is 1 ⇒ map to 3rd dim (there is only one channel)
        # 3rd dim 30 is max sentence length ⇒ map to 1st dim (this is the width of the data)
        # 1002 is the number of observations in the data. ⇒ map to 4th dim
    c1 = permutedims(b1, [3,1,2,4]); # This permutation does not look right, but gives the correct size output.

    tt = Int(floor(args.tt*size(c1,4)))
       ctrain = c1[:,:,:,1:tt];
       ctest = c1[:,:,:,tt+1:end];
       ltrain = convert(Array{Float32,1}, labels[1:tt]);
       ltest = convert(Array{Float32,1}, labels[tt+1:end]);
       # TODO: need to return some size information: longest sentence length will be variable.
   	return Flux.Data.DataLoader(ctrain, ltrain; batchsize=100, shuffle = true), Flux.Data.DataLoader(ctest, ltest), args
end

function s_split(x)
	# write to take a delimiter, but return a vector of strings, not substrings
	return convert(Array{String,1}, split(x))
end

function pad_sentence(tempSentence, maxl)
    if(length(tempSentence) <= maxl)
        sentence_length = length(tempSentence)
        padding_length = maxl - sentence_length
        padding = fill("<PAD>", padding_length)
        padded_sentence = vcat(tempSentence, padding)

        return padded_sentence
    else
        return tempSentence
    end
end 

#Function for creating dictionary of word frequencies
function Counter(d::DataFrame)
    outp = Dict{String,Int64}()
    for i = 1:size(d, 1)
        for j in split(d[i, 1])
            if haskey(outp, j)
                outp[j] += 1
            else
                outp[j] = 1
            end
        end
    end
    return outp
end
#Function for creating dictionary of word frequencies
