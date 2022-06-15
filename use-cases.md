# Use-cases for vaccination Centre (user = 'patients')

```plantuml

left to right direction
skinparam packageStyle rectangle

actor staff
actor user

rectangle appointment-pre-booking {
    staff --> (pre-register) : manually
    (pre-register) .> (capacity) : occupy
    (user) <-- (capacity) : appointment registered
}
```

```plantuml

left to right direction
skinparam packageStyle rectangle

actor user

rectangle appointment-call-in-booking-cancelling {
    (user) --> (book) : call in
    (capacity) <. (book) : occupy
    (cancel) <-- (user)
    (cancel) .> (capacity) : release
}
```

```plantuml

top to bottom direction
skinparam packageStyle rectangle

rectangle {
    actor user
    actor receptionist
    actor nurse
}

rectangle receive-vaccine-on-site {
    user --> (arrives at centre)
    (arrives at centre) --> (register at reception)
    (register at reception) --> receptionist : records user arrival
    (register at reception) --> (receive vaccine)
    (receive vaccine) --> (appointment system)
    (appointment system) --> (finish appointment)
    nurse --> (appointment system) : records vaccine received
}
```

```plantuml

top to bottom direction
skinparam packageStyle rectangle

rectangle {
    actor user
    actor receptionist
    actor nurse
}

rectangle refuse-vaccine-on-site {
    user --> (arrives at centre)
    (arrives at centre) --> (register at reception)
    (register at reception) --> receptionist : records user arrival
    (register at reception) --> (refuse vaccine)
    (refuse vaccine) --> (appointment system)
    (appointment system) --> (finish appointment)
    nurse --> (appointment system) : records vaccine refused
}
```
