# using the output of train_embedding.jl, try to train a network.


using CSVFiles, Flux, DataFrames


dat1 = DataFrame(load("embedded_data.csv"))

target = convert(Array{Float64,1}, dat1[:x1])

input = convert(Array{Float64,2}, dat1[:,[:x2, :x3, :x4, :x5, :x6, :x7, :x8, :x9, :x10, :x11, :x12, :x13, :x14, :x15, :x16, :x17, :x18, :x19, :x20, :x21, :x22]])


function predict(x)
    input*x .+ b
end


function loss(x,y)
    ŷ = predict(x)
    sum((y.-ŷ).^2)
end
