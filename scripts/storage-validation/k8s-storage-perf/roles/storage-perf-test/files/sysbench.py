###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

import shutil, os.path, re, sys, subprocess, csv

def runSysbench(threads, fileTotalSize, fileTestMode, fileBlockSize, fileIoMode, fileFsyncFreq, fileExtraFlags):
    prepare = ["sysbench", "--threads="+threads, "--file-num="+fileNum, "--test=fileio", "--file-total-size="+fileTotalSize, "--file-test-mode="+fileTestMode, "--file-block-size="+fileBlockSize, "--file-io-mode="+fileIoMode, "--file-fsync-freq="+fileFsyncFreq, "prepare"]
    runtest = ["sysbench", "--threads="+threads, "--file-num="+fileNum, "--test=fileio", "--file-total-size="+fileTotalSize, "--file-test-mode="+fileTestMode, "--file-block-size="+fileBlockSize, "--file-extra-flags="+fileExtraFlags, "run"]
    cleanup = ["sysbench", "--threads="+threads, "--file-num="+fileNum, "--test=fileio", "--file-total-size="+fileTotalSize, "--file-test-mode="+fileTestMode, "--file-block-size="+fileBlockSize, "--file-io-mode="+fileIoMode, "--file-fsync-freq="+fileFsyncFreq, "cleanup"]
    p1 = subprocess.Popen(prepare, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).wait()
    p2 = subprocess.Popen(runtest, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    out, err = p2.communicate()
    if err is None:
        return out.decode("utf-8")
    print(err)
    p3 = subprocess.Popen(cleanup, stdout=subprocess.PIPE).wait()
    return None

def getAvg(subDict):
    if subDict and len(subDict.values()) > 0:
        return round(sum(subDict.values())* 1.0/len(subDict.values()), 1)
    return 0

def computeAvgs(data, threads):
    dict_data = [
        {'Environment': data['environment'], 'Cluster Name': data['cluster_name'], 'Storage Type': data['storage_type'], 'PVC': data['pvc'], 'Test Name': data['test_name'], 'Thread Count': data['thread_count'], 'Reads/s': getAvg(data['throughput_read']), 
        'Writes/s': getAvg(data['throughput_write']), 'read Mb/s': getAvg(data['file_ops_read']), 'write Mb/s': getAvg(data['file_ops_write']), 'Total Time': getAvg(data['total_time']),
        'Latency Min': getAvg(data['latency_min']), 'Latency Avg': getAvg(data['latency_avg']), 'Latency Max': getAvg(data['latency_max']), 'Latency 95th': getAvg(data['latency_95th'])},
    ]
    return(dict_data)

def extractValue(text):
    if text:
        text = text[0].strip()
        values = text.split(' ')
        value = values[len(values)-1]
        if value[-1] == 's':
            value = value[:-1]
        return round(float(value), 1)
    return ''

def runtest(numOfTests, thread, fileTotalSize, fileNum, fileTestMode, fbs, fileIoMode, fileFsyncFreq, fileExtraFlags, environment, clusterName, storageType, pvc):
    data={}
    keys=['throughput_read', 'throughput_write', 'file_ops_read', 'file_ops_write', 'total_time', 'latency_min', 'latency_avg', 'latency_max', 'latency_95th']
    for key in keys:
        data[key] = {}
    for i in range(numOfTests):
        result= runSysbench(thread, fileTotalSize, fileTestMode, fbs, fileIoMode, fileFsyncFreq, fileExtraFlags)
        data['throughput_read'][i] = extractValue(re.findall(".*reads\/s.*\n", result, re.MULTILINE))
        data['throughput_write'][i] = extractValue(re.findall(".*writes\/s.*\n", result, re.MULTILINE))
        data['file_ops_read'][i] = extractValue(re.findall(".*read, MiB\/s.*\n", result, re.MULTILINE))
        data['file_ops_write'][i] = extractValue(re.findall(".*written, MiB\/s.*\n", result, re.MULTILINE))
        data['total_time'][i] = extractValue(re.findall(".*total time.*\n", result, re.MULTILINE))
        data['latency_min'][i] = extractValue(re.findall(".*min.*\n", result, re.MULTILINE))
        data['latency_avg'][i] = extractValue(re.findall(".*avg.*\n", result, re.MULTILINE))
        data['latency_max'][i] = extractValue(re.findall(".*max.*\n", result, re.MULTILINE))
        data['latency_95th'][i] = extractValue(re.findall(".*95th.*\n", result, re.MULTILINE))
    data['thread_count'] = thread
    data['test_name'] = fileTestMode+"_"+fbs+"_"+thread
    data['environment'] = environment
    data['cluster_name'] = clusterName
    data['storage_type'] = storageType
    data['pvc'] = pvc
    avgData = computeAvgs(data, thread)
    return avgData

if __name__=='__main__':
    if len(sys.argv) != 13:
        print("Usage: python3 sysbench.py <threads> <fileTotalSize> <fileNum> <fileTestMode> <fileBlockSize> <fileIoMode> <fileFsyncFreq> <fileExtraFlags> <environment> <clusterName> <storageType> <pvc>")
        sys.exit(1)
    numOfTests = 3
    threads=sys.argv[1].split(',')
    fileTotalSize=sys.argv[2]
    fileNum=sys.argv[3]
    fileTestMode=sys.argv[4]
    fileBlockSize=sys.argv[5].split(',')
    fileIoMode=sys.argv[6]
    fileFsyncFreq=sys.argv[7]
    fileExtraFlags=sys.argv[8]
    environment=sys.argv[9]
    clusterName=sys.argv[10]
    storageType=sys.argv[11]
    pvc=sys.argv[12]
    test_results = []
    for thread in threads:
        for fbs in fileBlockSize:
            res = runtest(numOfTests, thread, fileTotalSize, fileNum, fileTestMode, fbs, fileIoMode, fileFsyncFreq, fileExtraFlags, environment, clusterName, storageType, pvc)
            test_results.append(res[0])
    print(test_results)
