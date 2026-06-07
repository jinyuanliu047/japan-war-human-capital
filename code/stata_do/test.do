cd "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data"

import delimited using "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data/人民-日报-文本数据库.csv", clear

use "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data/stock_incentive/CG_EIPLAN.dta", clear
* Step 1: 保留主要变量（你可以根据需要增删）
keep Cdbsn EventID Stkcd Prgrsdt Firstdt Odate Incesub Incstktp Subsour ///
     Impstage Nincesubtl Protleuq Rspstkta Ratiortt Ratiortn ///
     Pnumber Exramount Teramount Excispri Priceway Awardway ///
     Givcond Procond Ratioex Validity Moratorium Firperiod Reperiod

* Step 2: 删除缺失证券代码或关键变量的记录（可调整）
drop if missing(Stkcd) | missing(Cdbsn) | missing(Prgrsdt)

* Step 3: 将日期变量统一为 Stata 日期格式（注意处理00值）
gen prgrsdt_date = daily(Prgrsdt, "YMD")
replace prgrsdt_date = . if strpos(Prgrsdt, "00")
format prgrsdt_date %td

gen firstdt_date = daily(Firstdt, "YMD")
replace firstdt_date = . if strpos(Firstdt, "00")
format firstdt_date %td

gen odate_date = daily(Odate, "YMD")
replace odate_date = . if strpos(Odate, "00")
format odate_date %td

* Step 4: 可选：删除未实施、已取消等记录（可保留"实施中"的）
drop if Impstage == "未实施" | strpos(Impstage, "取消")

* 是否是员工持股（常用于ESOP研究）
gen is_esop = (Incesub == "E")

* 激励对象总人数大于零
gen valid_award = (Pnumber > 0)

* 是否多次授予
gen multi_award = (Awardway == "2")

* 激励力度指标：激励总额占股本比
gen total_award_strength = Protleuq

* 激励预留占比
gen reserved_ratio = Ratiortt

* 查看不同激励方式的数量
tab Incesub

* 按年份 tab 一下披露数量（如你想构建面板）
gen year = year(prgrsdt_date)
tab year

* 检查部分记录
browse Stkcd prgrsdt_date Incesub Nincesubtl Protleuq

* 是否存在任何激励计划
gen has_incentive = !missing(Nincesubtl)

destring Stkcd, replace
rename Stkcd scode




