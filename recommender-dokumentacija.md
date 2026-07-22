# JetGo recommender dokumentacija

## 1. Svrha recommender sistema

JetGo koristi jednostavni, objasnjivi recommender za preporuku letova prijavljenom korisniku.
Sistem ne koristi machine learning model niti vanjski AI servis, nego bodovanje zasnovano na
stvarnim podacima iz baze:

- historiji pretraga korisnika,
- historiji rezervacija korisnika,
- globalnoj popularnosti rute medju svim korisnicima,
- trenutnoj dostupnosti buducih letova.

Cilj sistema je da korisniku na mobile aplikaciji prikaze letove koji su najrelevantniji na
osnovu njegovog ponasanja i postojece potraznje.

## 2. Gdje se nalazi glavna logika

Glavni fajlovi recommender sistema:

- [API/JetGo.Infrastructure/Services/RecommendationService.cs](API/JetGo.Infrastructure/Services/RecommendationService.cs)
- [API/JetGo.Infrastructure/Services/FlightService.cs](API/JetGo.Infrastructure/Services/FlightService.cs)
- [API/JetGo.API/Controllers/RecommendationsController.cs](API/JetGo.API/Controllers/RecommendationsController.cs)
- [API/JetGo.Application/DTOs/Recommendations/RecommendedFlightDto.cs](API/JetGo.Application/DTOs/Recommendations/RecommendedFlightDto.cs)
- [API/JetGo.Domain/Entities/SearchHistory.cs](API/JetGo.Domain/Entities/SearchHistory.cs)
- [Mobile/jetgo_mobile/lib/features/home/home_screen.dart](Mobile/jetgo_mobile/lib/features/home/home_screen.dart)

Uloge fajlova:

- `RecommendationService.cs`:
  - cita ulazne signale iz baze,
  - bira kandidate,
  - racuna bodove,
  - vraca objasnjive preporuke.
- `FlightService.cs`:
  - pri pretragama letova upisuje `SearchHistory` zapise koje recommender kasnije koristi.
- `RecommendationsController.cs`:
  - izlaže endpoint `GET /api/Recommendations/flights`.
- `RecommendedFlightDto.cs`:
  - definise koje polje odgovora klijent dobija.
- `home_screen.dart`:
  - poziva API za preporuke i prikazuje kartice "Preporuceno za vas".

## 3. Izvor podataka za preporuke

Recommender koristi tri stvarna izvora podataka iz baze.

### 3.1. SearchHistory

Entitet:

```csharp
public sealed class SearchHistory : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;
    public string SearchTerm { get; set; } = string.Empty;
    public int? DestinationId { get; set; }
    public Destination? Destination { get; set; }
}
```

Ovaj entitet se puni u `FlightService.cs` nakon korisnicke pretrage letova.

Sistem pamti samo pretrage koje su bitne za preporuke:

- `SearchText`
- `DepartureAirportId`
- `ArrivalAirportId`
- `AirlineId`

Ako korisnik pretrazuje konkretnu rutu polazak + dolazak, sistem pokusava pronaci odgovarajucu
`DestinationId` vrijednost i cuva i tu informaciju. Time recommender moze razlikovati:

- **egzaktnu pretragu rute**,
- **tekstualnu / kljucnu pretragu**.

Bitna napomena:

- u recommender se uzima **zadnjih 100 pretraga** korisnika.

### 3.2. Historija rezervacija korisnika

Recommender gleda koliko korisnik ima prethodnih ili aktivnih rezervacija po destinaciji/ruti,
pri cemu se otkazane rezervacije ignorisu.

Na taj nacin sistem prepoznaje da korisnik cesto putuje na istu rutu ili u isti grad.

### 3.3. Globalna popularnost

Recommender dodatno racuna koliko potvrđenih ili zavrsenih rezervacija postoji za istu
destinaciju medju svim korisnicima.

To daje signal da je ruta popularna i trazena.

## 4. Kandidati koji ulaze u preporuku

Prije bodovanja sistem bira samo letove koji imaju smisla za preporuku. U kandidat skup ulaze
samo letovi koji ispunjavaju sve ove uslove:

- status leta je `Scheduled`,
- polazak je u buducnosti,
- let ima slobodna sjedista,
- korisnik vec nema neotkazanu rezervaciju za taj isti let.

To znaci da recommender ne vraca:

- prosle letove,
- rasprodate letove,
- letove koji nisu aktivni,
- letove koje je korisnik vec rezervisao.

## 5. Signali i bodovanje

Za svaki kandidat let racunaju se sljedeca 4 signala:

1. `ExactRouteSearchCount`  
   Koliko puta je korisnik pretrazio bas tu destinaciju/rutu preko `DestinationId`.

2. `KeywordSearchCount`  
   Koliko korisnikovih tekstualnih pretraga se poklapa sa dokumentom leta
   (`RouteCode`, `FlightNumber`, naziv i kod aviokompanije, IATA kodovi i nazivi gradova).

3. `MatchingReservationCount`  
   Koliko korisnik vec ima prethodnih/aktivnih rezervacija na istoj destinaciji.

4. `PopularityCount`  
   Koliko potvrđenih ili zavrsenih rezervacija postoji na toj destinaciji medju svim korisnicima.

Formula bodovanja u `RecommendationService.cs` je:

```csharp
var recommendationScore =
    exactRouteSearchCount * 5 +
    keywordSearchCount * 3 +
    reservationCount * 6 +
    popularityCount * 2;
```

Znacenje tezina:

- **6** za historiju rezervacija: najjaci signal licne relevantnosti
- **5** za egzaktnu pretragu rute: vrlo jak signal namjere
- **3** za kljucne rijeci: srednje jak signal
- **2** za globalnu popularnost: pomocni signal

## 6. Objasnjive preporuke

Sistem ne vraca samo "score", nego i objasnjenje.

Svaka preporuka sadrzi:

- `RecommendationScore`
- `AppliedSignals`
- `RecommendationReason`

Primjeri `AppliedSignals` vrijednosti:

- `ExactRouteSearch`
- `KeywordSearch`
- `ReservationHistory`
- `GlobalPopularity`
- `FallbackUpcomingAvailability`

Ako nijedan personalizirani signal nije prisutan, sistem i dalje moze preporuciti narednu dostupnu
opciju i tada vraca fallback razlog:

> "Preporuceno kao naredna dostupna opcija jer jos nema dovoljno licne historije za precizniju preporuku."

## 7. Glavni tok rada recommendera

### Korak 1: korisnik pretrazuje letove

Mobile ili drugi klijent poziva `GET /api/Flights`.

Tokom te pretrage `FlightService` automatski upisuje `SearchHistory` zapis ako je pretraga
relevantna za recommender.

Relevantni dijelovi logike:

```csharp
private async Task TrackSearchHistoryAsync(FlightSearchRequest request, CancellationToken cancellationToken)
{
    if (request.Page != 1 || !HasRecommendationRelevantFilters(request))
    {
        return;
    }

    var userId = TryGetCurrentUserId();
    if (string.IsNullOrWhiteSpace(userId))
    {
        return;
    }

    var searchHistory = await BuildSearchHistoryAsync(userId, request, cancellationToken);
    if (searchHistory is null)
    {
        return;
    }

    await _dbContext.SearchHistories.AddAsync(searchHistory, cancellationToken);
    await _dbContext.SaveChangesAsync(cancellationToken);
}
```

### Korak 2: klijent trazi preporuke

Mobile aplikacija poziva:

```http
GET /api/Recommendations/flights
```

Endpoint se nalazi u:

- [API/JetGo.API/Controllers/RecommendationsController.cs](API/JetGo.API/Controllers/RecommendationsController.cs)

I dostupan je samo prijavljenom korisniku (`[Authorize]`).

### Korak 3: RecommendationService cita signale

Servis uzima:

- zadnjih 100 korisnikovih pretraga,
- korisnikove aktivne / prethodne rezervacije,
- globalnu popularnost ruta,
- skup buducih letova sa slobodnim mjestima.

### Korak 4: bodovanje i sortiranje

Preporuke se sortiraju ovim redoslijedom:

1. `RecommendationScore` opadajuce
2. `ExactRouteSearchCount` opadajuce
3. `KeywordSearchCount` opadajuce
4. `MatchingReservationCount` opadajuce
5. `PopularityCount` opadajuce
6. `DepartureAtUtc` rastuce
7. `BasePrice` rastuce

To znaci da se pri istom score-u prednost daje:

- letovima koji bolje odgovaraju korisnikovim signalima,
- ranijim polascima,
- jeftinijim opcijama.

## 8. Izlaz prema klijentu

Klijent dobija `PagedResponseDto<RecommendedFlightDto>`.

Najbitnija polja DTO-a:

```csharp
public int RecommendationScore { get; init; }
public int ExactRouteSearchCount { get; init; }
public int KeywordSearchCount { get; init; }
public int MatchingReservationCount { get; init; }
public int PopularityCount { get; init; }
public IReadOnlyCollection<string> AppliedSignals { get; init; }
public string RecommendationReason { get; init; } = string.Empty;
```

Pored recommender polja vracaju se i standardne informacije o letu:

- `Id`
- `FlightNumber`
- `RouteCode`
- `Airline`
- `DepartureAirport`
- `ArrivalAirport`
- `DepartureAtUtc`
- `ArrivalAtUtc`
- `DurationMinutes`
- `BasePrice`
- `AvailableSeats`
- `TotalSeats`
- `Status`

## 9. Prikaz u mobile aplikaciji

Mobile klijent preporuke ucitava u:

- [Mobile/jetgo_mobile/lib/features/home/home_screen.dart](Mobile/jetgo_mobile/lib/features/home/home_screen.dart)

Najbitniji dio toka:

- pri otvaranju taba "Letovi" poziva se `fetchRecommendedFlights`
- rezultat se sprema u `_recommendedFlights`
- kartice se prikazuju u sekciji **Preporuceno za vas**
- `recommendationReason` se prikazuje direktno korisniku na kartici

Na taj nacin recommender nije skriven servis u pozadini, nego vidljiva funkcionalnost aplikacije.

## 10. Kako testirati recommender

### Korak 1

Prijaviti se kao mobile korisnik:

- username: `mobile`
- password: `test`

### Korak 2

Vise puta pretraziti letove preko `GET /api/Flights`, npr:

- `SearchText=VIE`
- `SearchText=BNX VIE`
- `DepartureAirportId=3` i `ArrivalAirportId=5`

### Korak 3

Pozvati:

```http
GET /api/Recommendations/flights?page=1&pageSize=10
```

### Ocekivani rezultat

Za letove koji odgovaraju prethodnim pretragama treba rasti:

- `KeywordSearchCount`
- `ExactRouteSearchCount`
- `RecommendationScore`

U odgovoru treba biti i tekstualno objasnjenje, npr:

- da je korisnik tu rutu pretrazivao vise puta,
- da ima povezane pretrage,
- da vec ima historiju rezervacija na istoj ruti,
- da je ruta popularna medju korisnicima.

## 11. Ogranicenja trenutnog pristupa

Ovaj recommender je namjerno jednostavan i objasnjiv, sto je pogodno za seminarski rad.

Trenutna ogranicenja:

- koristi samo interne podatke iz aplikacije,
- ne koristi collaborative filtering niti ML model,
- ne uci iz eksplicitnih ocjena korisnika,
- ne koristi vremensko propadanje tezina po starosti pretrage,
- ne odvaja posebno poslovne i turisticke obrasce putovanja.

Ipak, za potrebe seminara ispunjava bitne uslove:

- koristi stvarne signale iz baze,
- preporuka nije simulirana,
- bodovanje je transparentno,
- rezultat je objasnjiv korisniku.

## 12. Zakljucak

JetGo recommender sistem je implementiran kao explainable scoring model nad letovima.
Ulazi u model se stvarno zapisuju kroz `SearchHistory`, rezervacije i popularnost ruta, a rezultat
se korisniku prikazuje na mobile aplikaciji kroz sekciju "Preporuceno za vas" zajedno sa razlogom
zasto je odredjeni let preporucen.
