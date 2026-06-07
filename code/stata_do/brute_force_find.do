local path "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war/data"
file open fh using "identified_pooled_files.txt", write replace

local subdirs : dir "`path'" dirs "*", respectcase
foreach d in `subdirs' {
    local files : dir "`path'/`d'" files "*.dta", respectcase
    foreach f in `files' {
        capture use "`path'/`d'/`f'", clear
        if _rc == 0 {
            capture confirm variable eduy ihs_rate
            if _rc == 0 {
                file write fh "FOUND: `path'/`d'/`f'" _n
            }
        }
    }
}
file close fh
exit, clear
