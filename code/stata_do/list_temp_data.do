cd "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war/data/temp"
local files : dir "." files "*.dta"
foreach f in `files' {
    di "CHECKING_FILE: `f'"
}
exit, clear
