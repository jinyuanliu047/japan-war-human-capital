# Extract needed IPUMS columns from the fixed-width .dat stream.
# Filters to birth cohorts 1910-1975 (birthyr = YEAR - AGE, since BIRTHYR field is blank
# for the China samples). GEO codes kept as strings to preserve leading digits.
# Data rows -> CSV (path in -v OUT=); progress lines -> stdout.
BEGIN { OFS = ","
        print "year,sample,serial,perwt,geo3_1982,geo3_1990,geo3_2000,urban,age,sex,ethniccn,school,lit,edattain,edattaind,educcn,empstat,empstatd,labforce,occisco,occ,indgen,ind,migrate5,birthyr" > OUT }
length($0) >= 360 {
    t++
    year = substr($0,4,4) + 0
    age  = substr($0,261,3) + 0
    by   = year - age
    if (by >= 1910 && by <= 1975) {
        k++
        print year, substr($0,8,9), substr($0,17,12)+0, substr($0,215,8)+0, \
              substr($0,175,9), substr($0,184,9), substr($0,193,9), \
              substr($0,75,1), age, substr($0,266,1), substr($0,303,2)+0, \
              substr($0,305,1), substr($0,306,1), substr($0,307,1), substr($0,308,3)+0, \
              substr($0,311,2)+0, substr($0,313,1), substr($0,314,3)+0, substr($0,317,1), \
              substr($0,319,2)+0, substr($0,321,4)+0, substr($0,325,3)+0, substr($0,328,5)+0, \
              substr($0,335,2)+0, by >> OUT
    }
    if (t % 2000000 == 0) { printf("progress read=%d kept=%d\n", t, k); fflush() }
}
END { printf("DONE read=%d kept=%d\n", t, k); fflush(); close(OUT) }
