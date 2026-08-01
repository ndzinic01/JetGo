# JetGo Desktop Test Plan

Ovaj dokument sluzi kao finalni checklist za testiranje desktop administratorske
aplikacije nakon resetovanja baze na cisto demo stanje.

## Preduvjeti

Prije testiranja provjeriti:

1. backend stack je podignut:

```powershell
docker compose up -d --build
```

2. desktop aplikacija je pokrenuta:

```powershell
cd Desktop\jetgo_desktop
C:\src\flutter\bin\flutter.bat run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Napomena:

- ako Windows prijavi gresku za symlink support, ukljuciti Developer Mode

3. seed nalozi su dostupni:

- admin: `desktop / test`
- korisnik 1: `mobile / test`
- korisnik 2: `mobile2 / test`

4. baza je u cistom demo stanju:

- nema seed rezervacija ni placanja
- letovi `JG100` do `JG105` su dostupni u decembru 2026

## Pravilo za testiranje

- desktop aplikacija se testira kao administratorski nalog `desktop`
- dio scenarija zavisi od prethodno kreiranih podataka sa mobile strane:
  - rezervacija
  - placanje
  - refund zahtjev kroz podrsku
- idealno je prije desktop testa prvo proci osnovni mobile test plan

## Faza 1 - Prijava i osnovna navigacija

### 1. Login kao desktop admin

Koraci:

- otvoriti aplikaciju
- unijeti:
  - korisnicko ime: `desktop`
  - lozinka: `test`
- kliknuti prijavu

Ocekivano:

- otvara se admin shell
- vidljiv je naziv `JetGo Admin`
- bocni meni prikazuje module:
  - Kontrolna tabla
  - Moj profil
  - Osnovni podaci
  - Rute i letovi
  - Rezervacije
  - Korisnici
  - Podrska
  - Novosti
  - Izvjestaji
  - Placanja

### 2. Provjera navigacije kroz meni

Koraci:

- redom otvoriti svaki modul iz bocnog menija

Ocekivano:

- svaki modul se otvara bez greske
- nema praznog ekrana ili zaglavljene navigacije

### 3. Logout i ponovna prijava

Koraci:

- kliknuti `Odjava`
- ponovo se prijaviti kao `desktop`

Ocekivano:

- korisnik se vraca na login ekran
- nova prijava radi bez problema

## Faza 2 - Kontrolna tabla

### 4. Pocetni pregled dashboarda

Koraci:

- otvoriti `Kontrolna tabla`

Ocekivano:

- vidi se pregled osnovnih metrika:
  - rezervacije
  - korisnici
  - podrska
  - placanja
  - refundirana placanja
- tekst je na bosanskom jeziku

### 5. Provjeriti auto-refresh dashboarda

Koraci:

- ostaviti `Kontrolna tabla` otvorenu oko 20 sekundi
- u medjuvremenu na mobile ili kroz Swagger napraviti neku promjenu:
  - novu rezervaciju
  - novi support upit
  - novo placanje

Ocekivano:

- dashboard se osvjezava automatski bez rucnog klika
- metrike se azuriraju

## Faza 3 - Moj profil

### 6. Pregled admin profila

Koraci:

- otvoriti `Moj profil`

Ocekivano:

- vide se osnovni podaci admina
- nema prikaza suvisnih internih sistemskih ID-eva

### 7. Uredjivanje profila

Koraci:

- kliknuti akciju za uredjivanje profila
- promijeniti telefon ili email
- sacuvati izmjene

Ocekivano:

- podaci su uspjesno sacuvani
- izmjene su odmah vidljive i u sidebar profilu

### 8. Promjena lozinke

Koraci:

- otvoriti dijalog za promjenu lozinke
- unijeti staru i novu lozinku

Ocekivano:

- promjena lozinke prolazi uspjesno
- nakon odjave prijava radi sa novom lozinkom

Napomena:

- po zelji lozinku vratiti nazad na `test` radi lakseg daljeg testiranja

## Faza 4 - Osnovni podaci

### 9. Drzave

Koraci:

- otvoriti `Osnovni podaci`
- ostati na tabu `Drzave`
- testirati:
  - live pretragu
  - dodavanje nove drzave
  - uredjivanje postojece drzave

Ocekivano:

- lista drzava se ucitava odmah
- pretraga filtrira rezultate
- create i edit rade bez overflow gresaka

### 10. Gradovi

Koraci:

- otvoriti tab `Gradovi`
- testirati:
  - live pretragu
  - filter `Sve drzave`
  - dodavanje novog grada
  - uredjivanje postojeceg grada

Ocekivano:

- dropdown `Sve drzave` je vizuelno ispravan
- dugme `Novi grad` je omoguceno kada postoje drzave
- create i edit grada rade ispravno

### 11. Aerodromi

Koraci:

- otvoriti tab `Aerodromi`
- testirati:
  - live pretragu
  - filter po drzavi
  - dodavanje novog aerodroma
  - uredjivanje postojeceg aerodroma

Ocekivano:

- dropdown filter je vizuelno ispravan
- dugme `Novi aerodrom` radi
- aerodrom se moze povezati sa gradom

### 12. Aviokompanije

Koraci:

- otvoriti tab `Aviokompanije`
- testirati:
  - live pretragu
  - dodavanje nove aviokompanije
  - uredjivanje postojece aviokompanije

Ocekivano:

- lista se filtrira ispravno
- create i edit rade bez greske

## Faza 5 - Rute i letovi

### 13. Rute

Koraci:

- otvoriti `Rute i letovi`
- ostati na tabu ruta
- testirati:
  - live pretragu
  - dodavanje nove rute
  - uredjivanje postojece rute

Ocekivano:

- ruta se moze kreirati izborom polaznog i dolaznog aerodroma
- lista ruta se osvjezava nakon izmjene

### 14. Letovi

Koraci:

- otvoriti tab `Letovi`
- testirati:
  - live pretragu
  - dodavanje novog leta
  - uredjivanje postojeceg leta

Ocekivano:

- moguce je unijeti:
  - broj leta
  - rutu
  - aviokompaniju
  - vremena polaska i dolaska
  - cijenu
  - broj sjedista
  - status

### 15. Statusi letova

Koraci:

- pregledati listu letova

Ocekivano:

- statusi su razumljivi i na bosanskom jeziku
- za letove u buducnosti status je tipicno `Zakazan`
- za letove ciji je dolazak u proslosti status prelazi u `Zavrsen`

## Faza 6 - Rezervacije

### 16. Pregled svih rezervacija

Preduvjet:

- mobile korisnik je prethodno napravio barem jednu rezervaciju

Koraci:

- otvoriti modul `Rezervacije`

Ocekivano:

- admin vidi listu svih rezervacija
- pretraga i filteri rade

### 17. Detalji rezervacije

Koraci:

- odabrati jednu rezervaciju iz liste

Ocekivano:

- vide se:
  - kupac
  - ruta i broj leta
  - sjedista
  - dodatni prtljag
  - ukupan iznos
  - payment status
  - refund dostupnost

### 18. Logika statusa rezervacije

Koraci:

- pregledati rezervaciju prije i poslije placanja

Ocekivano:

- rezervacija ne trazi rucni admin complete workflow
- nakon dolaska leta rezervacija automatski ide u `Zavrsena`

Napomena:

- dugme za rucni complete ne treba biti dio normalnog rada

## Faza 7 - Korisnici

### 19. Lista korisnika

Koraci:

- otvoriti modul `Korisnici`

Ocekivano:

- vide se korisnici `desktop`, `mobile` i `mobile2`
- pretraga radi

### 20. Detalji korisnika

Koraci:

- odabrati `mobile`
- zatim `mobile2`

Ocekivano:

- admin vidi osnovne podatke korisnika
- vidi broj rezervacija i placanja po korisniku

### 21. Uredjivanje korisnika

Koraci:

- otvoriti dijalog za uredjivanje korisnika
- promijeniti npr. ime ili telefon
- sacuvati izmjene

Ocekivano:

- podaci se uspjesno azuriraju

### 22. Aktivacija i deaktivacija korisnika

Koraci:

- testirati akciju aktivacije/deaktivacije nad `mobile2`

Ocekivano:

- status se mijenja nakon potvrde
- lista i detalji ostaju konzistentni

### 23. Reset lozinke korisnika

Koraci:

- otvoriti dijalog za reset lozinke nad `mobile2`
- postaviti privremenu novu lozinku

Ocekivano:

- reset prolazi uspjesno
- korisnik se moze prijaviti sa novom lozinkom

Napomena:

- po zelji vratiti `mobile2` lozinku nazad na `test`

## Faza 8 - Podrska

### 24. Lista support upita

Preduvjet:

- mobile korisnik je poslao barem jedan support upit

Koraci:

- otvoriti modul `Podrska`

Ocekivano:

- admin vidi listu korisnickih poruka
- status je `Na cekanju` ili `Odgovoreno`

### 25. Auto-refresh podrske

Koraci:

- ostaviti ekran `Podrska` otvoren oko 20 sekundi
- kao mobile poslati novi upit

Ocekivano:

- nova poruka se pojavljuje bez rucnog refresh-a

### 26. Odgovoriti na upit

Koraci:

- odabrati support poruku
- kliknuti `Odgovori` ili `Uredi odgovor`
- unijeti odgovor
- sacuvati

Ocekivano:

- odgovor se uspjesno salje iz prvog pokusaja
- status prelazi u `Odgovoreno`
- detalji prikazuju vrijeme odgovora

## Faza 9 - Novosti

### 27. Lista novosti

Koraci:

- otvoriti modul `Novosti`

Ocekivano:

- lista clanaka se ucitava
- admin vidi i detalje selektovane novosti

### 28. Kreiranje novosti

Koraci:

- kliknuti akciju za novu novost
- unijeti:
  - naslov
  - sadrzaj
  - image URL
  - published flag
- sacuvati

Ocekivano:

- nova novost je kreirana
- ako je objavljena, vidljiva je i na mobile strani

### 29. Uredjivanje postojece novosti

Koraci:

- odabrati postojecu novost
- urediti naslov ili sadrzaj
- sacuvati

Ocekivano:

- izmjene se odmah vide u detaljima

## Faza 10 - Izvjestaji

### 30. Preview rezervacijskog izvjestaja

Koraci:

- otvoriti modul `Izvjestaji`
- pregledati lijevu karticu za rezervacije
- promijeniti filter statusa i datumski raspon

Ocekivano:

- preview panel se ucitava bez overflow gresaka
- metrika i sample stavke odgovaraju filterima

### 31. Download reservations PDF

Koraci:

- kliknuti download za reservations PDF

Ocekivano:

- PDF se sacuva u folder:
  - `Downloads/JetGoReports`

### 32. Preview payment izvjestaja

Koraci:

- pregledati desnu karticu za placanja
- mijenjati status i datumske filtere

Ocekivano:

- preview pokazuje:
  - ukupan broj placanja
  - placena
  - refundirana
  - pending / failed

### 33. Download payments PDF

Koraci:

- kliknuti download za payments PDF
- po zelji kliknuti otvaranje foldera

Ocekivano:

- PDF se sacuva u `Downloads/JetGoReports`
- aplikacija prijavljuje uspjesno cuvanje izvjestaja

## Faza 11 - Placanja

### 34. Lista placanja

Preduvjet:

- mobile korisnik je prethodno inicirao i potvrdio barem jedno PayPal placanje

Koraci:

- otvoriti modul `Placanja`

Ocekivano:

- admin vidi listu svih payment zapisa
- pretraga i filter po statusu rade

### 35. Detalji placanja

Koraci:

- odabrati jedno `Paid` placanje

Ocekivano:

- vide se:
  - rezervacija
  - kupac
  - flight
  - status i timeline
  - refund dostupnost

### 36. PayPal provjera

Koraci:

- kliknuti `PayPal debug` na placanju

Ocekivano:

- prikazuju se samo korisne debug informacije:
  - status narudzbe
  - PayPal order ID
  - capture zapisi
  - klikabilni debug linkovi ako su dostupni

Napomena:

- ovo sluzi adminu za provjeru sta je PayPal vratio za konkretnu narudzbu

### 37. Refund placanja

Preduvjet:

- placanje je `Placeno`
- nije refundirano
- let je vise od 48h udaljen od polaska

Koraci:

- kliknuti `Refundiraj`
- unijeti razlog refundiranja
- potvrditi akciju

Ocekivano:

- placanje prelazi u `Refundirano`
- pojavljuje se vrijeme refundiranja
- korisnik dobija odgovarajucu informaciju kroz svoj tok

## Zavrsna provjera

Desktop aplikacija se smatra spremnom za finalno testiranje ako su potvrdjeni:

- login i logout
- kontrolna tabla sa auto-refresh logikom
- moj profil i promjena lozinke
- CRUD nad osnovnim podacima
- CRUD nad rutama i letovima
- pregled rezervacija
- upravljanje korisnicima
- support pregled i odgovaranje
- novosti create/edit flow
- reports preview i PDF download
- payments pregled, PayPal provjera i refund
- bosanski jezik i konzistentni statusi kroz cijeli UI
