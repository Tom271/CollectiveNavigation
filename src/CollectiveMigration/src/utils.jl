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

function load_HYCOM_data(file_path::String)
    sea = matread(file_path)
    data_name = " ";
    for i in keys(sea)
        println(i)
        data_name = i;
    end
    sea = sea[data_name];
    return sea
end