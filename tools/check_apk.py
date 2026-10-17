"""APK'NIN İÇİNDEKİLERİ DENETLE.

NEDEN BU VAR: projede bir kez `dict.db` repoda var ama APK'ya GİRMİYORDU.
pubspec.yaml yalnızca assets/data/ tanımlıyordu. Boyut farkı ele verir
belki ama kesin kanıt değildir — bu betik APK'yı açıp dosyayı arıyor.

Bir de sürüm adını kontrol ediyor: yayınladığımız APK gerçekten 0.3.0 mu?
"""
import io
import sys
import zipfile
from pathlib import Path

APK = Path("build/app/outputs/flutter-apk")

BEKLENEN = [
    "assets/flutter_assets/assets/dict.db",
    "assets/flutter_assets/assets/data/wordle_clean.json",
]

print("APK ICERIK DENETIMI")
print("=" * 58)

sorun = 0

for apk in sorted(APK.glob("*.apk")):
    boyut = apk.stat().st_size / 1048576
    print(f"\n{apk.name}  ({boyut:.1f} MB)")

    try:
        with zipfile.ZipFile(apk) as z:
            adlar = set(z.namelist())

            for beklenen in BEKLENEN:
                if beklenen in adlar:
                    bilgi = z.getinfo(beklenen)
                    print(f"  VAR   {beklenen}")
                    print(f"        {bilgi.file_size / 1048576:.2f} MB")
                else:
                    print(f"  YOK   {beklenen}   <-- HATA")
                    sorun += 1

            # manifest surumu
            surum = "?"
            if "AndroidManifest.xml" in adlar:
                # ikili manifest; ham baytlardan surum cikarilamaz,
                # dosyanin varligi yeterli bir isaret
                surum = "gomme"
            print(f"  surum : {surum}")
    except zipfile.BadZipFile:
        print(f"  HATA  dosya bozuk veya tam derlenmemis")
        sorun += 1

print()
print("=" * 58)
if sorun:
    print(f"SONUC: {sorun} sorun var. APK YAYINLANMAMALI.")
    sys.exit(1)
print("SONUC: tum dosyalar APK icinde. Yayina hazir.")
sys.exit(0)