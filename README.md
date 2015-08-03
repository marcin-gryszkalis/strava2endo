strava2endo
===========

Scripts to sync strava workouts to endomondo

## Usage


### strava-backup.pl [-f]
downloads all new workouts to ./gpx
add -f switch to check only first page (workouts are sorted by time, usually you need to check only first page to get latest workouts)

---

NOTE: endomondo upload is not working anymore because of changes on endomondo side. I recommend switching to Tapiriik https://github.com/cpfair/tapiriik 

---

### endomondo-upload.pl -g workout.gpx
upload given gpx to endomondo

### strava2endo.pl
compares 2 directories: ./gpx  and ./endomondo - then call ./endomondo-upload.pl -g ... for every file in ./gpx but not in ./endomondo - after successful upload copies given file from ./gpx to ./endomondo
