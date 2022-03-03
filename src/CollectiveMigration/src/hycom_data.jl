#``` Load the raw HYCOM file
# Will output latitude, longitude, water velocity in u and v, and times.
#```
function load_sea_data(filepath::String)

    sea = matread(filepath)
    for i in keys(sea)
        println(i)
        data_name = i
    end
    sea = sea[data_name]
    return sea
end

#``` Process HYCOM data 
# Transform data to grid 
# Normalise so strongest velocity is 1.
#   # How do we do that? Calculate norm([u v]) and use that? Won't be the quickest for the whole data set but only happens once. 
# Normalise time to scale with number of agents/events. 
#```

#``` Interpolate HYCOM data
# For a given t,x,y, (i.e. vector of positions) find the nearest points in the HYCOM data and 
# 1. use the nearest points 
# 2. linearly interpolate between them.
# 3. more complicated thing? unnecessary.
# Analogous to `flow_at()` function. 
#```
