ARG IMAGE_TAG

FROM ${IMAGE_TAG} AS builder

RUN mkdir -p /work

WORKDIR /work

COPY index.ts package.json tsconfig.json /work/

RUN yarn install \
 && yarn build

FROM ${IMAGE_TAG}

COPY --from=builder /work/index.js /work/package.json /var/task/

WORKDIR /var/task/
RUN yarn install --production

ENTRYPOINT [ "/var/task/bootstrap" ]
CMD [ "/var/task/index.handler" ]
