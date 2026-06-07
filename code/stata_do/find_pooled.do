local path "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war/data"
local files : dir "`path'" files "*.dta", respectcase
foreach f in `files' {
    capture use "`path'/`f'", clear
    capture confirm variable wave eduy
    if _rc == 0 {
        di "FOUND_MASTER_IN_ROOT: `f'"
    }
}

local subdirs : dir "`path'" dirs "*", respectcase
foreach d in `subdirs' {
    local subfiles : dir "`path'/`d'" files "*.dta", respectcase
    foreach sf in `subfiles' {
        capture use "`path'/`d'/`sf'", clear
        capture confirm variable wave eduy
        if _rc == 0 {
            di "FOUND_MASTER_IN_SUBDIR: `path'/`d'/`sf'"
        }
    }
}
exit, clear
