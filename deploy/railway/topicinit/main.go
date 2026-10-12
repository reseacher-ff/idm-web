// topicinit ensures the Kafka topic used by idm exists before the server starts.
// The idm consumer subscribes with OffsetNewest at startup; if the topic does
// not exist yet, real-time download processing silently degrades to the 1-minute
// cron fallback. This helper removes that race. It never fails the deploy:
// on any error it logs and exits 0 (the cron job remains as a fallback).
package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/IBM/sarama"
)

const topic = "download_task_created"

func main() {
	brokers := strings.Split(os.Getenv("KAFKA_BROKERS"), ",")
	if len(brokers) == 0 || brokers[0] == "" {
		fmt.Println("topicinit: KAFKA_BROKERS not set, skipping")
		return
	}

	cfg := sarama.NewConfig()
	cfg.ClientID = "idm-topicinit"
	cfg.Metadata.Full = true

	deadline := time.Now().Add(90 * time.Second)
	for {
		if err := ensureTopic(brokers, cfg); err == nil {
			fmt.Printf("topicinit: topic %q ready\n", topic)
			return
		} else {
			fmt.Printf("topicinit: %v, retrying...\n", err)
		}
		if time.Now().After(deadline) {
			fmt.Println("topicinit: giving up, server will rely on cron fallback")
			return
		}
		time.Sleep(3 * time.Second)
	}
}

func ensureTopic(brokers []string, cfg *sarama.Config) error {
	admin, err := sarama.NewClusterAdmin(brokers, cfg)
	if err != nil {
		return fmt.Errorf("admin client: %w", err)
	}
	defer admin.Close()

	topics, err := admin.ListTopics()
	if err != nil {
		return fmt.Errorf("list topics: %w", err)
	}
	if _, ok := topics[topic]; ok {
		return nil
	}

	err = admin.CreateTopic(topic, &sarama.TopicDetail{
		NumPartitions:     1,
		ReplicationFactor: 1,
	}, false)
	if err != nil {
		// Already exists (race) is fine.
		if strings.Contains(err.Error(), "already exists") {
			return nil
		}
		return fmt.Errorf("create topic: %w", err)
	}
	return nil
}
