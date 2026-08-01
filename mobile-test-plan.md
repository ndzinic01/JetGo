# JetGo Mobile Test Plan

Ovaj dokument sluzi kao finalni checklist za testiranje mobilne aplikacije nakon
resetovanja baze na cisto demo stanje.

## Preduvjeti

Prije testiranja provjeriti:

1. backend stack je podignut:

```powershell
docker compose up -d --build
```

2. mobilna aplikacija je pokrenuta na Android emulatoru:

```powershell
cd Mobile\jetgo_mobile
C:\src\flutter\bin\flutter.bat run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

3. seed nalozi su dostupni:

- korisnik 1: `mobile / test`
- korisnik 2: `mobile2 / test`
- admin: `desktop / test`

4. baza je u cistom demo stanju:

- nema seed rezervacija
- nema seed placanja
- letovi `JG100` do `JG105` su seedani u decembru 2026

## Pravilo za testiranje

- prvo proci kompletan korisnicki tok sa nalogom `mobile`
- zatim po potrebi provjeriti odvojeni scenario sa nalogom `mobile2`
- za refund scenario koristi se kombinacija:
  - mobile korisnik salje zahtjev
  - admin refund odobrava kroz desktop ili Swagger

## Faza 1 - Prijava i osnovna navigacija

### 1. Login kao mobile korisnik

Koraci:

- otvoriti aplikaciju
- unijeti:
  - korisnicko ime: `mobile`
  - lozinka: `test`
- kliknuti prijavu

Ocekivano:

- otvara se pocetni ekran aplikacije
- nema zamrzavanja na loginu
- vidi se glavni naslov `JetGo Mobile`

### 2. Provjera glavne navigacije

Koraci:

- otvoriti meni u gornjem desnom uglu
- proci kroz stavke:
  - Letovi
  - Rezervacije
  - Novosti
  - Podrska
  - Moj profil

Ocekivano:

- svaka stavka otvara odgovarajuci ekran
- nema praznih ili nefunkcionalnih ekrana

### 3. Logout i ponovna prijava

Koraci:

- otvoriti meni
- odabrati odjavu
- ponovo se prijaviti kao `mobile`

Ocekivano:

- korisnik se vraca na login ekran
- nova prijava radi bez greske

## Faza 2 - Letovi i preporuke

### 4. Pocetna lista letova

Koraci:

- otvoriti ekran `Letovi`

Ocekivano:

- seed letovi su vidljivi
- za svaki let se prikazuju:
  - ruta
  - broj leta
  - vrijeme polaska
  - vrijeme dolaska
  - cijena

### 5. Preporuceno za vas

Koraci:

- na vrhu ekrana pregledati sekciju `Preporuceno za vas`

Ocekivano:

- prikazuju se kartice preporucenih destinacija
- slike odgovaraju stvarnim destinacijama
- nema overflow oznaka

Napomena:

- na potpuno cistom nalogu preporuke mogu biti bazirane na fallback logici
- nakon nekoliko pretraga i rezervacija preporuke trebaju postati smislenije

### 6. Otvoriti detalje leta

Koraci:

- kliknuti bilo koji let sa liste

Ocekivano:

- otvara se ekran `Detalji leta`
- vide se:
  - polazni i dolazni aerodrom
  - broj leta
  - dozvoljeni prtljag
  - raspored sjedista
  - sekcija za dodatni prtljag

### 7. Provjeriti raspored sjedista

Koraci:

- na detaljima leta pregledati mapu sjedista

Ocekivano:

- slobodna i rezervisana sjedista su vizuelno jasno odvojena
- broj slobodnih sjedista odgovara stvarnom stanju
- moguce je oznaciti jedno ili vise slobodnih mjesta

## Faza 3 - Rezervacija i dodatni prtljag

### 8. Kreirati rezervaciju bez dodatnog prtljaga

Koraci:

- na detaljima leta oznaciti jedno slobodno sjediste
- ostaviti opciju `Bez dodatnog prtljaga`
- kliknuti `Rezervisi`

Ocekivano:

- rezervacija je uspjesno kreirana
- otvara se potvrda ili detalj rezervacije
- ukupna cijena odgovara osnovnoj cijeni karte

### 9. Kreirati rezervaciju sa dodatnim prtljagom

Koraci:

- otvoriti drugi let
- oznaciti slobodno sjediste
- odabrati jednu konkretnu ponudu dodatnog prtljaga
- kliknuti `Rezervisi`

Ocekivano:

- rezervacija je kreirana
- dodatni prtljag je vidljiv u detaljima rezervacije
- ukupna cijena ukljucuje i doplatu za prtljag

### 10. Provjeriti listu rezervacija

Koraci:

- otvoriti ekran `Rezervacije`

Ocekivano:

- nova rezervacija se pojavljuje na listi
- za svaku stavku se prikazuju:
  - reservation code
  - ruta
  - vrijeme polaska
  - vrijeme dolaska
  - cijena
  - status

### 11. Provjeriti detalje rezervacije

Koraci:

- otvoriti jednu rezervaciju sa liste

Ocekivano:

- vide se:
  - rezervisana sjedista
  - iznos za sjedista
  - dodatni prtljag
  - ukupan iznos
  - payment status

## Faza 4 - PayPal placanje

### 12. Inicirati placanje

Koraci:

- na detaljima rezervacije kliknuti `1. Otvori PayPal`

Ocekivano:

- payment se inicira
- otvara se PayPal approval stranica

### 13. Zavrsiti PayPal approval

Koraci:

- prijaviti se sa ispravnim PayPal sandbox personal nalogom
- odobriti placanje

Ocekivano:

- browser vraca korisnika nazad u mobilnu aplikaciju
- aplikacija prikazuje poruku da je PayPal odobrenje zaprimljeno
- postaje dostupan korak `2. Zavrsi placanje`

### 14. Potvrditi placanje u aplikaciji

Koraci:

- kliknuti `2. Zavrsi placanje`

Ocekivano:

- placanje prelazi u stanje `Placeno`
- rezervacija vise ne ceka placanje
- u rezervaciji se vidi da je payment evidentiran

### 15. Provjeriti ponovni ulazak u detalje rezervacije

Koraci:

- vratiti se na listu rezervacija
- ponovo otvoriti upravo placenu rezervaciju

Ocekivano:

- status i dalje ostaje `Placeno`
- nema potrebe za ponovnim PayPal approval korakom

## Faza 5 - Refund zahtjev sa mobile strane

### 16. Provjeriti da li je refund zahtjev dostupan

Koraci:

- otvoriti detalje placene rezervacije

Ocekivano:

- ako je let vise od 48h udaljen, postoji akcija `Zatrazi refund`
- ako uslovi nisu ispunjeni, refund akcija nije dostupna

### 17. Poslati refund zahtjev kroz podrsku

Koraci:

- kliknuti `Zatrazi refund`
- potvrditi slanje

Ocekivano:

- otvara se forma za podrsku ili se zahtjev automatski salje kao podrska poruka
- korisnik dobija potvrdu da je zahtjev poslan

Napomena:

- mobile korisnik ne izvrsava refund direktno
- mobile korisnik samo pokrece zahtjev, a refund odobrava admin

## Faza 6 - Podrska i odgovori administracije

### 18. Otvoriti podrsku

Koraci:

- otvoriti ekran `Podrska`

Ocekivano:

- vidi se lista korisnickih upita
- statistika na vrhu ekrana je ucitana

### 19. Poslati novi upit

Koraci:

- kliknuti `Novi upit`
- unijeti naslov i poruku
- poslati

Ocekivano:

- novi upit se pojavljuje na listi
- status je `Ceka`

### 20. Provjeriti auto-refresh odgovora

Koraci:

- kao admin odgovoriti na upit kroz desktop ili Swagger
- ostaviti mobile ekran `Podrska` otvoren oko 20 sekundi

Ocekivano:

- bez rucnog refresh-a status upita se azurira
- odgovor administratora postaje vidljiv

## Faza 7 - Notifikacije

### 21. Otvoriti ekran notifikacija

Koraci:

- kliknuti ikonu zvona

Ocekivano:

- otvara se lista notifikacija
- neprocitane stavke su jasno oznacene

### 22. Provjeriti auto-refresh notifikacija

Koraci:

- kao admin uraditi neku akciju koja generise notifikaciju:
  - odgovor na podrsku
  - refund
- ostaviti mobile ekran otvoren oko 20 sekundi

Ocekivano:

- nova notifikacija se pojavljuje bez rucnog refresh-a

### 23. Oznaciti notifikaciju kao procitanu

Koraci:

- otvoriti ili oznaciti jednu notifikaciju kao procitanu

Ocekivano:

- broj neprocitanih se smanjuje
- status se odmah azurira u UI-ju

## Faza 8 - Novosti

### 24. Otvoriti ekran novosti

Koraci:

- kroz meni otvoriti `Novosti`

Ocekivano:

- vidi se lista objavljenih novosti
- slike se pravilno ucitavaju
- prikaz je uredan i pregledan

### 25. Provjeriti novu admin novost

Koraci:

- kao admin kreirati novu objavljenu novost
- vratiti se na mobile i sacekati refresh ili rucno osvjeziti ekran

Ocekivano:

- nova novost je vidljiva i na mobile strani

## Faza 9 - Moj profil

### 26. Otvoriti moj profil

Koraci:

- kroz meni otvoriti `Moj profil`

Ocekivano:

- vide se osnovni podaci korisnika
- nema prikaza internih sistemskih ID-eva
- tekst i kartice su vizuelno poravnati i citljivi

### 27. Urediti profil

Koraci:

- otvoriti `Uredi profil`
- promijeniti telefon ili sliku
- sacuvati izmjene

Ocekivano:

- izmjene su uspjesno sacuvane
- po povratku na profil vide se novi podaci

### 28. Promijeniti lozinku

Koraci:

- otvoriti `Promijeni lozinku`
- unijeti staru i novu lozinku

Ocekivano:

- lozinka se uspjesno mijenja
- nakon odjave prijava radi sa novom lozinkom

Napomena:

- radi lakseg daljeg testiranja lozinku po zelji vratiti nazad na `test`

## Faza 10 - Odvojeni scenario sa drugim seed korisnikom

### 29. Login kao mobile2

Koraci:

- odjaviti `mobile`
- prijaviti se kao:
  - korisnicko ime: `mobile2`
  - lozinka: `test`

Ocekivano:

- drugi korisnik ima svoj odvojeni profil
- ne vidi rezervacije korisnika `mobile`

### 30. Provjeriti izolaciju podataka

Koraci:

- otvoriti `Rezervacije`, `Podrska` i `Notifikacije`

Ocekivano:

- korisnik `mobile2` vidi samo svoje podatke
- nema mijesanja rezervacija, notifikacija i support poruka izmedju korisnika

## Zavrsna provjera

Mobilna aplikacija se smatra spremnom za finalno testiranje ako su potvrdjeni:

- login i logout
- navigacija kroz sve ekrane
- prikaz letova i preporuka
- detalji leta i sjedista
- rezervacija sa i bez dodatnog prtljaga
- lista i detalji rezervacija
- PayPal approval povratak u aplikaciju
- finalna potvrda placanja
- refund zahtjev kroz podrsku
- podrska i odgovor administratora
- notifikacije sa auto-refresh logikom
- novosti
- moj profil, uredjivanje profila i promjena lozinke
- izolacija podataka izmedju `mobile` i `mobile2`
