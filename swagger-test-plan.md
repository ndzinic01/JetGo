# JetGo Swagger Test Plan

Ovaj dokument sluzi kao finalni checklist za backend testiranje kroz Swagger nakon
resetovanja baze na cisto demo stanje.

## Preduvjeti

Prije testiranja:

1. iz root foldera pokrenuti:

```powershell
docker compose down -v
docker compose up -d --build
```

2. otvoriti Swagger:

- `http://localhost:5000/swagger`

3. pripremiti seed naloge:

- admin: `desktop / test`
- korisnik 1: `mobile / test`
- korisnik 2: `mobile2 / test`

## Pravilo za tok testiranja

- prvo testirati korisnicki tok kao `mobile`
- zatim administratorski tok kao `desktop`
- gdje god dobijes JWT token iz `POST /api/Auth/login`, klikni `Authorize` u Swaggeru i
  zalijepi:

```text
Bearer <accessToken>
```

## Faza 1 - Osnovna autentifikacija i profil

### 1. Login kao mobile korisnik

Endpoint:

- `POST /api/Auth/login`

Body:

```json
{
  "username": "mobile",
  "password": "test"
}
```

Ocekivano:

- `200 OK`
- vraca `accessToken`
- korisnik ima rolu `User`

### 2. Provjera trenutnog korisnika

Endpoint:

- `GET /api/Auth/me`

Ocekivano:

- `200 OK`
- username je `mobile`

### 3. Profil korisnika

Endpointi:

- `GET /api/Profile/me`
- `PUT /api/Profile/me`

Primjer update body:

```json
{
  "firstName": "Mobile",
  "lastName": "User",
  "email": "mobile@jetgo.local",
  "phoneNumber": "+38761000002",
  "imageUrl": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=600&q=80"
}
```

Ocekivano:

- `GET` vraca profil
- `PUT` vraca azuriran profil

### 4. Promjena lozinke

Endpoint:

- `POST /api/Profile/change-password`

Body:

```json
{
  "currentPassword": "test",
  "newPassword": "test123",
  "confirmPassword": "test123"
}
```

Ocekivano:

- `204 No Content`

Napomena:

- odmah nakon toga opet testirati `POST /api/Auth/login` sa novom lozinkom
- po zelji vratiti lozinku nazad na `test` istim endpointom radi lakseg daljeg testiranja

## Faza 2 - Letovi, pretrage i preporuke

### 5. Lista seed letova

Endpoint:

- `GET /api/Flights`

Ocekivano:

- `200 OK`
- vidljivi seed letovi `JG100` do `JG105`
- svi su u buducnosti, u decembru 2026

### 6. Detalji leta

Endpoint:

- `GET /api/Flights/1`

Ocekivano:

- `200 OK`
- vraca broj slobodnih i rezervisanih sjedista

### 7. Napuniti search history za preporuke

Pozvati nekoliko puta:

- `GET /api/Flights?arrivalAirportId=5`
- `GET /api/Flights?searchText=VIE`
- `GET /api/Flights?searchText=Vienna`
- `GET /api/Flights?departureAirportId=1&arrivalAirportId=5`

Ocekivano:

- svaki poziv vraca rezultate
- search history se puni u pozadini

### 8. Preporuke

Endpoint:

- `GET /api/Recommendations/flights`

Ocekivano:

- `200 OK`
- vraca preporucene letove
- u rezultatu postoje polja:
  - `recommendationScore`
  - `appliedSignals`
  - `recommendationReason`

## Faza 3 - Rezervacija i dodatni prtljag

### 9. Kreirati rezervaciju

Endpoint:

- `POST /api/Reservations`

Body:

```json
{
  "flightId": 1,
  "seatNumbers": ["1A", "1B"],
  "additionalBaggageCount": 0
}
```

Ocekivano:

- `200 OK`
- vraca `reservationCode`
- rezervacija je aktivna i spremna za placanje

### 10. Provjeriti moje rezervacije

Endpoint:

- `GET /api/Reservations/my`

Ocekivano:

- nova rezervacija se pojavljuje na listi

### 11. Detalji rezervacije

Endpoint:

- `GET /api/Reservations/{reservationId}`

Ocekivano:

- vide se sjedista, cijena i payment stanje

### 12. Azurirati dodatni prtljag prije placanja

Endpoint:

- `PUT /api/Reservations/{reservationId}/baggage`

Body:

```json
{
  "additionalBaggageCount": 2
}
```

Ocekivano:

- `200 OK`
- ukupna cijena je preracunata
- dodatni prtljag je azuriran

## Faza 4 - PayPal placanje

### 13. Inicirati placanje

Endpoint:

- `POST /api/Payments/reservations/{reservationId}/initialize`

Ocekivano:

- `200 OK`
- vraca `paymentId`
- vraca `approvalUrl`
- status je `Pending`

### 14. Odobriti PayPal placanje u browseru

Korak:

- otvoriti `approvalUrl` iz prethodnog odgovora
- prijaviti se sa ispravnim PayPal sandbox personal nalogom
- zavrsiti approval

Ocekivano:

- otvara se JetGo povratna HTML stranica
- prikazuje poruku da je PayPal odobrenje zaprimljeno

### 15. Potvrditi placanje na serveru

Endpoint:

- `POST /api/Payments/{paymentId}/confirm`

Body:

```json
{}
```

Ocekivano:

- `200 OK`
- payment status prelazi u `Paid`
- reservation postaje placena

### 16. Provjera mojih placanja

Endpoint:

- `GET /api/Payments/my`

Ocekivano:

- na listi postoji novo placanje
- status je `Paid`

## Faza 5 - Podrska i notifikacije

### 17. Poslati korisnicki upit

Endpoint:

- `POST /api/SupportMessages`

Body:

```json
{
  "subject": "Pitanje oko refunda",
  "message": "Zelim provjeriti pod kojim uslovima mogu traziti refund za ovu rezervaciju."
}
```

Ocekivano:

- `200 OK`
- upit je kreiran

### 18. Moji upiti

Endpoint:

- `GET /api/SupportMessages/my`

Ocekivano:

- novi upit je vidljiv na listi

### 19. Moje notifikacije

Endpointi:

- `GET /api/Notifications/summary`
- `GET /api/Notifications`

Ocekivano:

- postoji barem jedna notifikacija za rezervaciju ili placanje
- summary pokazuje broj neprocitanih

### 20. Oznaciti notifikaciju kao procitanu

Endpoint:

- `POST /api/Notifications/{id}/read`

Ocekivano:

- `204 No Content`
- nakon toga summary ima manji `unreadCount`

## Faza 6 - Administratorski tok

### 21. Login kao desktop admin

Endpoint:

- `POST /api/Auth/login`

Body:

```json
{
  "username": "desktop",
  "password": "test"
}
```

Ocekivano:

- `200 OK`
- korisnik ima rolu `Admin`

### 22. Admin dashboard summary

Endpoint:

- `GET /api/AdminDashboard/summary`

Ocekivano:

- `200 OK`
- summary prikazuje broj korisnika, placanja, rezervacija i podrske

### 23. Pregled svih rezervacija

Endpoint:

- `GET /api/Reservations`

Ocekivano:

- admin vidi rezervaciju koju je kreirao `mobile`

### 24. Pregled svih placanja

Endpoint:

- `GET /api/Payments`

Ocekivano:

- admin vidi payment u statusu `Paid`

### 25. PayPal debug pregled

Endpoint:

- `GET /api/Payments/{paymentId}/debug-paypal`

Ocekivano:

- `200 OK`
- vraca PayPal snapshot sa statusom i linkovima

### 26. Pregled podrske

Endpoint:

- `GET /api/SupportMessages`

Ocekivano:

- admin vidi korisnicki upit iz prethodnog koraka

### 27. Odgovoriti na korisnicki upit

Endpoint:

- `POST /api/SupportMessages/{supportMessageId}/reply`

Body:

```json
{
  "adminReply": "Refund je moguc samo za placenu rezervaciju i najkasnije 48 sati prije polaska leta."
}
```

Ocekivano:

- `200 OK`
- upit dobija administratorski odgovor
- korisniku se pravi notifikacija

### 28. Povratak na mobile notifikacije

Ponovo kao `mobile` pozvati:

- `GET /api/Notifications`
- `GET /api/SupportMessages/my`
- `GET /api/SupportMessages/{supportMessageId}`

Ocekivano:

- korisnik vidi novu notifikaciju
- vidi odgovor administratora na upit

## Faza 7 - Refund

### 29. Refund placanja kao admin

Endpoint:

- `POST /api/Payments/{paymentId}/refund`

Body:

```json
{
  "reason": "Refund odobren na zahtjev korisnika."
}
```

Ocekivano:

- `200 OK`
- payment status prelazi u `Refunded`

### 30. Potvrda refund rezultata

Endpointi:

- `GET /api/Payments/{paymentId}`
- `GET /api/Payments`

Ocekivano:

- payment je sada `Refunded`
- postoji `refundedAtUtc`

## Faza 8 - Novosti

### 31. Javni pregled novosti kao mobile

Endpoint:

- `GET /api/News`

Ocekivano:

- vracaju se samo objavljene novosti

### 32. Kreirati novu novost kao admin

Endpoint:

- `POST /api/News`

Body:

```json
{
  "title": "Testna novost za Swagger",
  "content": "Ovo je testna novost kreirana tokom finalnog backend testiranja.",
  "imageUrl": "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1200&q=80",
  "isPublished": true,
  "publishedAtUtc": "2026-08-01T12:00:00Z"
}
```

Ocekivano:

- `200 OK`
- admin je vidi i kroz `GET /api/News/admin`
- korisnik je vidi i kroz `GET /api/News`

## Faza 9 - Admin CRUD nad rutama i letovima

### 33. Kreirati novu destinaciju

Endpoint:

- `POST /api/admin/destinations`

Body:

```json
{
  "departureAirportId": 1,
  "arrivalAirportId": 6,
  "isActive": true
}
```

Ocekivano:

- `200 OK`
- kreirana je nova ruta

### 34. Kreirati novi let na novoj destinaciji

Endpoint:

- `POST /api/admin/flights`

Body:

```json
{
  "airlineId": 3,
  "destinationId": 7,
  "flightNumber": "JG220",
  "departureAtUtc": "2026-12-20T09:00:00Z",
  "arrivalAtUtc": "2026-12-20T10:10:00Z",
  "basePrice": 111.00,
  "totalSeats": 6,
  "status": 1
}
```

Napomena:

- ako `destinationId` nakon kreiranja ne bude `7`, koristi stvarni ID iz odgovora Swaggera

Ocekivano:

- `200 OK`
- let se pojavljuje u `GET /api/admin/flights`

## Faza 10 - Pravila koja treba svjesno provjeriti

### 35. Rucni complete rezervacije vise nije dozvoljen

Kao admin pozvati:

- `POST /api/Reservations/{reservationId}/complete`

Body:

```json
{
  "reason": "Test"
}
```

Ocekivano:

- `400 Bad Request`
- poruka objasnjava da rezervacija automatski prelazi u `Completed` nakon dolaska leta

### 36. Refund nije dozvoljen za neplaceno placanje

Na nekom `Pending` ili nepostojecem `Paid` payment scenariju pokusati refund.

Ocekivano:

- `400` ili `409`
- jasna poruka da refund nije moguc

### 37. Dodatni prtljag nije dozvoljen nakon uspjesnog placanja

Nakon `Paid` stanja pokusati:

- `PUT /api/Reservations/{reservationId}/baggage`

Ocekivano:

- `409 Conflict`
- jasna poruka da izmjena vise nije dozvoljena

## Zavrsna provjera

Backend se smatra spremnim za finalno testiranje ako su kroz Swagger potvrdjeni:

- login i autorizacija
- profil i promjena lozinke
- letovi i preporuke
- rezervacija i dodatni prtljag
- PayPal initialize + confirm
- support + notifikacije
- admin pregled rezervacija i placanja
- refund
- novosti
- admin CRUD nad rutama i letovima
- pravilo da rezervacija vise ne ide rucno u `Completed`
