// vim: ts=4: 
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>

#include <linux/spi/spidev.h>

#define MAX_FILE_SIZE 4096

int main(int argc, char *argv[])
{
    const char *spi_dev = "/dev/spidev0.0";
    const char *file_name = "../fabulous/efpga/user_design/micro_uart.bin";

    if (argc > 1)
        file_name = argv[1];

    uint8_t file_buf[MAX_FILE_SIZE];
    uint8_t tx_buf[MAX_FILE_SIZE + 1];
    uint8_t rx_buf[MAX_FILE_SIZE + 1];

    FILE *fp = fopen(file_name, "rb");
    if (!fp) {
        perror("fopen");
        return 1;
    }

    size_t file_len = fread(file_buf, 1, sizeof(file_buf), fp);
    fclose(fp);

    printf("Read %zu bytes from %s\n", file_len, file_name);

    tx_buf[0] = 0x00;                     // configuration-load command
    memcpy(&tx_buf[1], file_buf, file_len);

    size_t tx_len = file_len + 1;

    memset(rx_buf, 0, tx_len);

    int fd = open(spi_dev, O_RDWR);
    if (fd < 0) {
        perror("open spidev");
        return 1;
    }

    uint8_t mode = SPI_MODE_0;
    uint8_t bits = 8;
    uint32_t speed = 100000;              // 100 kHz

    if (ioctl(fd, SPI_IOC_WR_MODE, &mode) < 0) {
        perror("SPI_IOC_WR_MODE");
        return 1;
    }

    if (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits) < 0) {
        perror("SPI_IOC_WR_BITS_PER_WORD");
        return 1;
    }

    if (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed) < 0) {
        perror("SPI_IOC_WR_MAX_SPEED_HZ");
        return 1;
    }

    struct spi_ioc_transfer tr = {
        .tx_buf = (unsigned long)tx_buf,
        .rx_buf = (unsigned long)rx_buf,
        .len = tx_len,
        .speed_hz = speed,
        .bits_per_word = bits,
        .delay_usecs = 0,
    };

    printf("\nSending %zu-byte configuration transaction...\n", tx_len);

    if (ioctl(fd, SPI_IOC_MESSAGE(1), &tr) < 1) {
        perror("SPI_IOC_MESSAGE");
        return 1;
    }

    printf("Configuration load complete.\n");

    //
    // Forever send CMD=2 plus four data bytes
    //
    uint8_t tx5[5];
    uint8_t rx5[5];

    tx5[0] = 0x02;

    uint32_t counter = 0;

    while (1) {

        tx5[1] = (counter >> 24) & 0xff;
        tx5[2] = (counter >> 16) & 0xff;
        tx5[3] = (counter >>  8) & 0xff;
        tx5[4] = (counter >>  0) & 0xff;

        memset(rx5, 0, sizeof(rx5));

        struct spi_ioc_transfer tr5 = {
            .tx_buf = (unsigned long)tx5,
            .rx_buf = (unsigned long)rx5,
            .len = 5,
            .speed_hz = speed,
            .bits_per_word = bits,
            .delay_usecs = 0,
        };

        if (ioctl(fd, SPI_IOC_MESSAGE(1), &tr5) < 1) {
            perror("SPI_IOC_MESSAGE");
            break;
        }

        printf("TX:");
        for (int i = 0; i < 5; i++)
            printf(" %02X", tx5[i]);

        printf("    RX:");
        for (int i = 0; i < 5; i++)
            printf(" %02X", rx5[i]);

        printf("\n");

        fflush(stdout);

        counter++;

        usleep(100000);   // 100 ms, remove/change as desired
    }

    close(fd);
    return 0;
}
