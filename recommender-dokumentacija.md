# JetGo recommender dokumentacija

## 1. Svrha recommender sistema

JetGo koristi objasnjivi sistem preporuke letova za prijavljenog mobilnog korisnika.
Algoritam je uskladjen sa prijavom teme: koristi **User-Based Collaborative Filtering**.

Ideja algoritma je da se za trenutnog korisnika pronadju drugi korisnici sa slicnim ponasanjem,
a zatim se preporuce buduci dostupni letovi/rute koje su ti slicni korisnici trazili ili
rezervisali, a trenutni korisnik ih jos nije rezervisao.

Za korisnike bez dovoljno historije ili bez pronadjenih slicnih korisnika koristi se fallback
strategija popularnosti, odnosno najtrazenije buduce dostupne rute u sistemu.

## 2. Glavni fajlovi

Glavna implementacija nalazi se u sljedecim fajlovima:

- [API/JetGo.Infrastructure/Services/RecommendationService.cs](API/JetGo.Infrastructure/Services/RecommendationService.cs)
- [API/JetGo.Infrastructure/Services/FlightService.cs](API/JetGo.Infrastructure/Services/FlightService.cs)
- [API/JetGo.API/Controllers/RecommendationsController.cs](API/JetGo.API/Controllers/RecommendationsController.cs)
- [API/JetGo.Application/DTOs/Recommendations/RecommendedFlightDto.cs](API/JetGo.Application/DTOs/Recommendations/RecommendedFlightDto.cs)
- [API/JetGo.Domain/Entities/SearchHistory.cs](API/JetGo.Domain/Entities/SearchHistory.cs)
- [Mobile/jetgo_mobile/lib/features/home/home_screen.dart](Mobile/jetgo_mobile/lib/features/home/home_screen.dart)

Uloge:

- `FlightService.cs` upisuje stvarne korisnicke search signale pri pretrazi letova.
- `SearchHistory.cs` cuva strukturirane signale po ruti, polazistu, odredistu i aviokompaniji.
- `RecommendationService.cs` gradi korisnicke profile, racuna slicnost korisnika i vraca preporuke.
- `RecommendationsController.cs` izlaze endpoint `GET /api/Recommendations/flights`.
- Mobile aplikacija prikazuje sekciju `Preporuceno za vas` i objasnjenje kroz opciju `Zasto?`.

## 3. Podaci koji ulaze u recommender

Recommender koristi stvarne podatke iz baze, a ne simulirane podatke.

### 3.1. SearchHistory

`SearchHistory` se puni kada korisnik pretrazuje letove. Nakon dorade signal vise nije samo jedan
spojeni tekst, nego sadrzi i strukturirana polja:

```csharp
public sealed class SearchHistory : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;
    public string SearchTerm { get; set; } = string.Empty;
    public int? DestinationId { get; set; }
    public int? DepartureAirportId { get; set; }
    public int? ArrivalAirportId { get; set; }
    public int? AirlineId { get; set; }
}
```

Primjer: ako korisnik trazi polaziste Sarajevo, odrediste Bec i aviokompaniju W6, backend cuva
odvojene signale za polazni aerodrom, dolazni aerodrom i aviokompaniju. `SearchTerm` ostaje samo
kao pomocni tekstualni zapis i dodatni tokenizovani signal.

### 3.2. Historija rezervacija

Rezervacije su jaci signal od pretraga. U recommender ulaze potvrdjene i zavrsene rezervacije,
jer one predstavljaju stvarno korisnicko ponasanje. Otkazane rezervacije se ne koriste kao
pozitivan signal.

Za rezervaciju se u profil korisnika dodaju signali:

- destinacija/ruta,
- polazni aerodrom,
- dolazni aerodrom,
- aviokompanija,
- tokeni iz route code vrijednosti.

### 3.3. Popularnost

Popularnost se koristi kao fallback za cold-start slucajeve, npr. kada korisnik nema dovoljno
pretraga/rezervacija ili kada nema drugih korisnika sa slicnim profilom. Tada sistem preporucuje
buduce dostupne rute koje imaju najvise potvrdjenih ili zavrsenih rezervacija.

## 4. Koraci algoritma

### Korak 1: Izgradnja korisnickih profila

Za svakog korisnika sistem gradi profil interesa. Profil je vektor karakteristika, npr:

- `destination:3`
- `departure-airport:1`
- `arrival-airport:4`
- `airline:2`
- `token:SJJ`
- `token:IST`

Rezervacije imaju vecu tezinu od pretraga, jer rezervacija znaci jaci interes korisnika.
Pretrage se ipak koriste jer pokazuju namjeru korisnika i pomazu u pronalasku slicnih korisnika.

### Korak 2: Pronalazak slicnih korisnika

Za trenutnog korisnika sistem poredi njegov profil sa profilima drugih korisnika. Slicnost se
racuna cosine similarity formulom nad vektorima karakteristika:

```text
similarity(A, B) = dot(A, B) / (|A| * |B|)
```

U preporuke ulaze samo korisnici koji imaju pozitivnu slicnost iznad minimalnog praga.
Sistem zatim uzima najvise 10 najslicnijih korisnika.

### Korak 3: Bodovanje kandidata

Kandidati su samo letovi koji se stvarno mogu preporuciti korisniku:

- let je u buducnosti,
- status je `Scheduled` ili `Delayed`,
- aviokompanija je aktivna,
- destinacija je aktivna,
- let ima slobodna sjedista,
- korisnik vec nema aktivnu rezervaciju za taj let,
- korisnik jos nije rezervisao tu destinaciju/rutu.

Za svaki kandidat sistem gleda koliko se taj let poklapa sa interesima slicnih korisnika.
Bod se dobija iz kombinacije:

- slicnosti drugog korisnika sa trenutnim korisnikom,
- jacine interesa slicnog korisnika za destinaciju, aerodrome, aviokompaniju i tokene kandidata,
- broja rezervacija slicnih korisnika za tu rutu,
- pomocnih search signala trenutnog korisnika kao tie-breaker,
- popularnosti kao fallback signala.

Pojednostavljeno:

```text
collaborativeScore = suma(similarity(currentUser, otherUser) * interest(otherUser, candidateFlight))
```

Ako postoji collaborative score, on je glavni faktor sortiranja. Ako ne postoji, koristi se
popularnost i buduca dostupnost.

## 5. Objasnjive preporuke

Endpoint vraca objasnjenje preporuke kroz `RecommendationReason` i listu `AppliedSignals`.

Primjeri razloga:

- `Preporuceno jer korisnici sa slicnim pretragama i rezervacijama imaju interes za rutu SJJ-IST...`
- `Preporuceno kao popularna buduca opcija jer jos nema dovoljno slicnih korisnika...`
- `Preporuceno kao naredna dostupna opcija jer jos nema dovoljno historije za pronalazak slicnih korisnika.`

Time korisnik vidi zasto je bas taj let preporucen, a sistem ispunjava zahtjev za objasnjivim
preporukama.

## 6. Search signali

Pretraga letova na mobilnoj aplikaciji salje filtere backendu odvojeno:

- `departureSearchText`
- `arrivalSearchText`
- `airlineCode`
- `departureAirportId`
- `arrivalAirportId`
- `airlineId`
- `searchText`

Backend vise ne tretira kombinaciju poput `Sarajevo Vienna W6` kao jedan jedini substring signal.
Umjesto toga pokusava povezati pretragu sa konkretnim aerodromima, rutom i aviokompanijom.
Tekstualni dio se dodatno tokenizuje na nezavisne pojmove, pa se `Sarajevo`, `Vienna` i `W6`
koriste kao odvojeni signali.

## 7. Cold-start strategija

Ako korisnik nema historiju ili sistem ne pronadje slicne korisnike, koristi se popularity-based
fallback. To je u skladu sa prijavom teme, gdje je navedeno da se za nove korisnike prikazuju
popularne destinacije iz narednog vremenskog perioda.

Fallback i dalje postuje ista poslovna pravila kao collaborative dio: ne preporucuju se prosli,
otkazani, neaktivni, rasprodani niti vec rezervisani letovi.

## 8. Zakljucak

JetGo recommender je implementiran kao User-Based Collaborative Filtering nad stvarnim ponasanjem
korisnika. Pretrage i rezervacije formiraju profile korisnika, cosine similarity pronalazi slicne
korisnike, a preporuke se formiraju iz interesa tih slicnih korisnika. Popularnost se koristi samo
kao fallback kada nema dovoljno podataka za collaborative filtering.
