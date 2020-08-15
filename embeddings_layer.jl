

## Mousa version - slightly different.



# Embeddings Layer

const embtable = load_embeddings(Embeddings.GloVe)

# const get_word_index = Dict(word=>ii for (ii,word) in enumerate(embtable.vocab))

# function get_embedding(word)
#     ind = get_word_index[word]
#     emb = embtable.embeddings[:,ind]
#     return emb
# end
#
# hopefullyYellow = get_embedding("blue") + get_embedding("green")

# Main embedding layer defined to just be an "E", which will be a matrix of Floats
    # includes a function σ which might not be used.
struct Embed{A<:AbstractArray,F<:Function}
    E::A # embeddings
    σ::F # function
end

# slight redefinition to permit a parameter d which specifies the dimension of the embedding
# and to handle key error, since some words may be unseen, also takes the dictionary, embtable
# rewrite or write separate function
function get_embedding(word, d, word_index, embtab)
    if haskey(word_index, word)
        ind = word_index[word]
        emb = embtab.embeddings[1:d,ind]
        return emb
    else
        return zeros(Float32, d)
    end
end

function embed_all(vocab, d, word_index, embtab)
    outp = Array{Array{Real, 1}, 1}()
    for v in vocab
        push!(outp, get_embedding(v, d, word_index, embtab))
    end
    return reduce(hcat, outp)
end

# When called as a function on a vocabulary and a dimension for the embedding
# the embed layer should load the embeddings, make the dict, pass it to get_embedding
function Embed(vocab::AbstractArray, d::Int, embtab, f = identity)
    word_index = Dict(word=>ii for (ii,word) in enumerate(embtab.vocab))
    return Embed(embed_all(vocab, d, word_index, embtab), f)
end

function Embed(vocab::AbstractArray, d::Int, emtab)
   return Embed(vocab, d, emtab, identity)
end

# define as function call - take the layer E and multiply by the vector x, apply σ
function (L::Embed)(x::AbstractArray)
    W, σ = L.E, L.σ
    return σ.(W*x)
end

# defining this is not necessary, but will display potentially useful information about the
# Embed layer.

function Base.show(io::IO, l::Embed)
    print(io, "Embed Layer(", size(l.E, 2), " Words, Embedding Length ", size(l.E,1), ")" )
    l.σ == identity || print(io, ", ", l.σ)
    print(io, ")")
end

# IF we want to make the values in the embedding layer trainable (i.e., to change the values)
# of the embeddings in response to errors, we need to use the function trainable.
    # Not clear that both this line and the Flux.trainable line are necessary
@functor Embed
Flux.trainable(L::Embed) = (L.E,)
