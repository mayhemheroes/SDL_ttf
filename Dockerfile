# Build Stage
FROM --platform=linux/amd64 ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y clang cmake make libsdl2-dev

## Add source code to the build stage.
WORKDIR /
ADD . /SDL_ttf
WORKDIR SDL_ttf

## Build
RUN mkdir build
WORKDIR build
RUN CC=clang CFLAGS="-fPIC" cmake -DINSTRUMENT=1 ..
RUN make -j$(nproc)

## Package Stage
FROM --platform=linux/amd64 ubuntu:20.04
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y libsdl2-dev
COPY --from=builder /SDL_ttf/build/fuzz/SDL2_ttf-fuzzer /SDL2_ttf-fuzzer
COPY --from=builder /SDL_ttf/build/libSDL2_ttf-2.0.so.0 /usr/lib
COPY --from=builder /SDL_ttf/fuzz/corpus /corpus

## Set up fuzzing!
ENTRYPOINT []
CMD /SDL2_ttf-fuzzer /corpus
