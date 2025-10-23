# superimpose

superimpose is a bash script for macOS. (it may work on other systems with some prodding)

you can use it for A4 PDF booklet imposition. it converts A5/A6 documents into print-ready A4 spreads for folded booklet print production.

it's intended for people making zines and other small publications on their home printer who have found that:

- popular publishing apps like Affinity Publisher *suck* at imposition
- good imposition software costs $ $ $ (e.g. $599)

this is what it does:

![superimpose](https://github.com/user-attachments/assets/f4cd9fe3-d45b-4793-bc37-2042a19f34d2)

(but you can have any number of pages so long as it's a multiple of 4 (A5) or 8 (A6))

## How to set up superimpose

1. Download superimpose.sh
2. Download and install [MaCTeX](https://www.tug.org/mactex/mactex-download.html) - this is required for pdfjam

You may also need to install poppler:
1. Install [homebrew](https://brew.sh/) if you don't have it
2. brew install poppler

## How to use superimpose

1. Create your booklet or zine at A5 or A6 size using your favourite document creation tool.
2. Export it with a normal page order (1, 2, 3, 4... you get the idea). Due to how booklets work, the pages must be a multiple of 4 (A5) or 8 (A6).
3. Run superimpose on your PDF:

``` ./superimpose.sh pathto/inputdoc.pdf pathto/outputdoc.pdf ```

4. That's it!
