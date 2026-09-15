# Model AI Racik

Taruh dua file hasil ekspor Teachable Machine di folder ini:

| File | Isi |
|---|---|
| `racik_food.tflite` | model (Export Model → TensorFlow Lite → Floating point) |
| `labels.txt` | daftar label, satu per baris, mis. `0 Nasi Goreng` |

Aturan penting: **setiap label harus sama persis dengan `foods.name`** di
database (huruf besar/kecil boleh beda). Aplikasi mencocokkan tebakan AI ke
resep lewat nama.

Selama file belum ada, aplikasi otomatis memakai `DemoFoodRecognizer`
dan menampilkan pita "Mode demo".
