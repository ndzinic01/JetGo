# JetGo

JetGo je seminarski rad za predmet Razvoj softvera II. Aplikacija omogucava
pretragu letova, rezervaciju sjedista, placanje preko PayPal sandbox okruzenja,
refund, notifikacije, novosti, korisnicku podrsku i administraciju sistema.

Sistem se sastoji od:

- REST API backend servisa
- RabbitMQ worker servisa za asinhrone notifikacije
- Flutter Windows desktop aplikacije za administraciju
- Flutter Android mobilne aplikacije za korisnike

## 1. Konfiguracija prije pokretanja

Aplikacija se nece ispravno pokrenuti bez `.env` fajla.

U root folderu projekta treba raspakovati sifriranu arhivu `.env-tajne.zip` tako
da se `.env` fajl nalazi direktno pored `docker-compose.yml`:

```text
JetGo/
  .env
  docker-compose.yml
  README.md
```

`.env` sadrzi konfiguraciju za:

- bazu podataka
- JWT autentifikaciju
- RabbitMQ
- Mailpit / SMTP
- PayPal sandbox
- CORS
- PayPal buyer test podatke

Primjer strukture konfiguracije nalazi se u:

- [`.env.example`](.env.example)

Raw `.env` fajl se ne commita u Git.

## 2. Sta je potrebno za pokretanje

Za pregled aplikacije potrebno je imati:

- Docker Desktop
- Android Studio sa pokrenutim Android emulatorom

Backend se pokrece kroz Docker, a desktop i mobilna aplikacija se mogu pokrenuti
iz pripremljenih build foldera.

## 3. Pokretanje backend-a

Iz root foldera projekta pokrenuti:

```powershell
docker compose up -d --build
```

Ova komanda pokrece:

- SQL Server bazu
- JetGo REST API
- JetGo Worker
- RabbitMQ
- Mailpit lokalni email inbox

Provjera da su servisi pokrenuti:

```powershell
docker compose ps
```

Nakon uspjesnog pokretanja API je dostupan na:

- `http://localhost:5000/swagger`

## 4. Pokretanje desktop aplikacije

Desktop aplikacija se pokrece iz release foldera:

```text
Desktop/jetgo_desktop/build/windows/x64/runner/Release/jetgo_desktop.exe
```

Za desktop aplikaciju API adresa je:

```text
http://localhost:5000
```

## 5. Pokretanje mobilne aplikacije

Prvo pokrenuti Android emulator.

Zatim instalirati APK fajl:

```text
Mobile/jetgo_mobile/build/app/outputs/flutter-apk/app-release.apk
```

Najjednostavnije je prevuci `app-release.apk` direktno na otvoreni emulator.
Nakon instalacije otvoriti aplikaciju JetGo Mobile.

Za Android emulator API adresa mora biti:

```text
http://10.0.2.2:5000
```

## 6. Test korisnici

Seed podaci kreiraju sljedece korisnike:

| Uloga | Korisnicko ime | Lozinka |
| --- | --- | --- |
| Desktop administrator | `desktop` | `test` |
| Mobilni korisnik | `mobile` | `test` |
| Dodatni mobilni korisnik | `mobile2` | `test` |

## 7. PayPal testiranje

Placanje je implementirano preko stvarnog PayPal sandbox toka.

PayPal buyer podaci za rucno testiranje nalaze se u `.env` fajlu pod:

- `JETGO_PAYPAL_SANDBOX_BUYER_EMAIL`
- `JETGO_PAYPAL_SANDBOX_BUYER_PASSWORD`

Tok placanja:

1. mobilni korisnik kreira rezervaciju
2. korisnik inicira placanje
3. aplikacija otvara PayPal sandbox approval stranicu
4. tester se prijavljuje buyer sandbox nalogom
5. nakon odobrenja placanja korisnik se vraca u aplikaciju
6. aplikacija poziva server-side confirm endpoint
7. rezervacija dobija status placanja `Placeno`

## 8. Korisne adrese

Nakon pokretanja Docker stacka dostupno je:

| Servis | Adresa |
| --- | --- |
| Swagger | `http://localhost:5000/swagger` |
| RabbitMQ Management UI | `http://localhost:15672` |
| Mailpit inbox | `http://localhost:8025` |
| SQL Server | `localhost,1433` |

Mailpit se koristi za testiranje zaboravljene lozinke. Email ne ide na stvarni
mail nalog, nego se prikazuje u lokalnom inboxu na `http://localhost:8025`.

## 9. Reset na cisto testno stanje

Ako je potrebno obrisati stare rezervacije, placanja i testne podatke, iz root
foldera pokrenuti:

```powershell
docker compose down -v
docker compose up -d --build
```

Ovo brise Docker volumene i ponovo kreira bazu. API pri pokretanju automatski:

- primjenjuje EF migracije
- kreira bazu `220035`
- dodaje test korisnike
- dodaje referentne podatke, destinacije, letove i novosti

Nakon cistog reseta nema starih rezervacija, placanja, refund zahtjeva,
notifikacija ni support upita.

## 10. Pokretanje iz source koda

Aplikacije se mogu pokrenuti i direktno iz source koda.

Desktop:

```powershell
cd Desktop\jetgo_desktop
C:\src\flutter\bin\flutter.bat run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Mobile:

```powershell
cd Mobile\jetgo_mobile
C:\src\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

## 11. Kratak pregled modula

Desktop aplikacija sadrzi administrativne module:

- kontrolna tabla
- moj profil
- osnovni podaci
- rute i letovi
- rezervacije
- korisnici
- podrska
- novosti
- placanja
- izvjestaji

Mobilna aplikacija sadrzi korisnicke module:

- registracija i prijava
- pregled letova
- preporuke
- detalji leta
- rezervacije
- placanje
- refund zahtjev kroz podrsku
- novosti
- notifikacije
- moj profil
- podrska

Backend ukljucuje autentifikaciju, autorizaciju, CRUD operacije, validaciju,
paginaciju, PayPal integraciju, refund logiku, PDF izvjestaje, RabbitMQ
notifikacije i sistem preporuke.

## 12. Struktura projekta

```text
API/
  JetGo.API              REST API
  JetGo.Application      DTO, request modeli, interfejsi i konstante
  JetGo.Domain           domenski entiteti i enum-i
  JetGo.Infrastructure   EF Core, Identity, servisi, seed, PayPal, RabbitMQ

Worker/
  JetGo.Worker           odvojeni RabbitMQ worker servis

Desktop/
  jetgo_desktop          Flutter Windows admin aplikacija

Mobile/
  jetgo_mobile           Flutter Android korisnicka aplikacija
```

## 13. Dokumentacija sistema preporuke

Opis recommender sistema nalazi se u:

- [recommender-dokumentacija.md](recommender-dokumentacija.md)

Dokument opisuje koje signale sistem koristi, kako se racuna score i kako se
korisniku prikazuje razlog preporuke.

## 14. Dodatne napomene

### PayPal sandbox

Bitne napomene:

- baza i aplikacija rade u `BAM`, ali se PayPal iznos po potrebi konvertuje u konfigurabilnu valutu
- `initialize` vraca approval URL
- `confirm` vrsi server-side capture
- `refund` koristi stvarno evidentiran naplaceni iznos
- mobile aplikacija prikazuje korake za otvaranje PayPal approval toka i zavrsetak placanja
- sandbox buyer email i lozinka iz `.env` sluze samo za rucno logovanje u PayPal sandbox tokom pregleda rada
- aplikacija ne popunjava PayPal login automatski; tester ove podatke rucno unosi na PayPal sandbox stranici

### Poslovna pravila

Najbitnija pravila implementirana u sistemu:

- rezervacija automatski prelazi kroz statusni tok
- korisnik moze imati vise rezervacija za isti let
- refund je dozvoljen samo za placenu rezervaciju koja nije refundirana i samo do 48h prije polaska
- rezervacija prelazi u `Completed` nakon dolaska leta
- recommender koristi stvarne signale iz aplikacije, a ne simulirane podatke

### Korisne napomene

- Za desktop aplikaciju API adresa treba biti `http://localhost:5000`
- Za Android emulator API adresa treba biti `http://10.0.2.2:5000`
- Ako testiras samo backend, dovoljno je otvoriti Swagger
- Ako testiras notifikacije i worker tok, RabbitMQ i worker moraju biti aktivni
- Za placanja je potrebno popuniti validne PayPal sandbox podatke u `.env`
