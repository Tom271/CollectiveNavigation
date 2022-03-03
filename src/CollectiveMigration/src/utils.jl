function open_save_file(save_dir, save_name)
    if save_name == ""
        date = Dates.now()
        name = Dates.format(date, "yyyy_mm_dd_HH_MM_SS")
    else
        name = save_name
    end
    touch(save_dir * "\\$name.tsv")
    file = open(save_dir * "\\$name.tsv", "a")
    return file, name
end

function logmessage(flow_value, sensing_value)
    # current time
    time = Dates.format(now(UTC), dateformat"yyyy-mm-dd HH:MM:SS")

    # memory the process is using 
    maxrss = "$(round(Sys.maxrss()/1048576, digits=2)) MiB"

    logdata = (; flow_value, sensing_value, maxrss) # lastly the amount of memory being used

    println(
        savename(
            time,
            logdata;
            connector = " | ",
            equals = " = ",
            sort = false,
            digits = 2,
        ),
    )
end

function load_HYCOM_data(file_path::String)
    sea = matread(file_path)
    data_name = " "
    for i in keys(sea)
        println(i)
        data_name = i
    end
    sea = sea[data_name]
    return sea
end
