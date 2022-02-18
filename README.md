# FSM
researches on fsm

# Concept

BLoC, dans les faits, fonctionne exactement comme une machine de Mealy, mais personne ne semble en avoir concience.
Le pattern BLoC partage les mêmes entrées et sortie qu'une machine de Mealy, mais aucune restriction n'est faite sur l'organisation interne du code et des états. C'est pour cette raison que meme avec BLoC on retombe dans les meme travers qu'avec GetX.

En soi, BLoC et Mealy sont tout à fait complémentaires. Bloc fournit l'infrastructure et Mealy régit le fonctionnement interne du bloc.

# CODE

la plupart des projets de state machine en javascript utilise un format similiaire
```js
let machine = {
    "state": {
        "transition": "newState",
    }
}
```

- les states sont réferencés à l'aide d'IDs en l'occurence un string. Cet ID doit être facilement accessible et idéalement checker au compile-time, pour éviter à la machine de transitioner vers un état inconue. 

- certains projet sépare la déclaration des transitions de la déclaration des states. Je ne crois pas que ce soit une bonne idée. Dans les cas les plus complexes, des utilisateurs peuvent être amené a travailler sur certaines  partie de la machine sans en connaitre l'intégralitée. Il sera plus pratique d'avoir accès au partie conecerné à un seul et meme endroit.

# Ressources
https://en.wikipedia.org/wiki/Mealy_machine

https://www.smashingmagazine.com/2018/01/rise-state-machines/

https://krasimirtsonev.com/blog/article/managing-state-in-javascript-with-state-machines-stent
