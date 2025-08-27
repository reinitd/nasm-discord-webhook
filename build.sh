nasm -f elf64 discord_webhook.asm -o discord_webhook.o
ld discord_webhook.o -o discord_webhook
rm discord_webhook.o
