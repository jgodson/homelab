FROM node:22-alpine

WORKDIR /app

COPY --chown=node:node package.json video-pipe.mjs ./

EXPOSE 8091

USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8091/health || exit 1

CMD ["node", "video-pipe.mjs"]
