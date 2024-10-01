# midiplayer
### midi file playback for norns

this simple script allows you to load your midi files into norns and play them back via nb.

this script is a proof-of-concept and a placeholder for a fully featured version that is in the works.
thanks to [possseidons](https://github.com/Possseidon/lua-midi) midi-lua library, midiplayer converts the midi data into pattern data which the reflection library useds to play back the notes.

**requirements:**
- norns
- [nb](https://llllllll.co/t/n-b-et-al-v0-1/60374) pre-installed
- nb voices pre-installed e.g polyperc, doubledecker, emplaitress
- midi files

**documentation:**

- Navigate to the parameters and select an nb voice.
- Press K3 to load a midi file. midi files are located under `code/midiplayer/midi_files/`
- Press K2 to toggle playback. Looping is currently disabled as I need to find a method to extract the exact midi file length.
